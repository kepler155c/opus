
-- see: https://github.com/luarocks/luarocks/blob/master/src/luarocks/tools/tar.lua
-- A pure-Lua implementation of untar (unpacking .tar archives)
local Util = require('opus.util')

local fs = _G.fs
local _sub = string.sub

local blocksize = 512

local function get_typeflag(flag)
	if flag == "0" or flag == "\0" then return "file"
	elseif flag == "1" then return "link"
	elseif flag == "2" then return "symlink" -- "reserved" in POSIX, "symlink" in GNU
	elseif flag == "3" then return "character"
	elseif flag == "4" then return "block"
	elseif flag == "5" then return "directory"
	elseif flag == "6" then return "fifo"
	elseif flag == "7" then return "contiguous" -- "reserved" in POSIX, "contiguous" in GNU
	elseif flag == "x" then return "next file"
	elseif flag == "g" then return "global extended header"
	elseif flag == "L" then return "long name"
	elseif flag == "K" then return "long link name"
	end
	return "unknown"
end

local function octal_to_number(octal)
	local exp = 0
	local number = 0
	octal = octal:gsub("%s", "")
	for i = #octal,1,-1 do
		local digit = tonumber(octal:sub(i,i))
		if not digit then
			break
		end
		number = number + (digit * 8^exp)
		exp = exp + 1
	end
	return number
end

local function checksum_header(block)
	local sum = 256
	for i = 1,148 do
		local b = block:byte(i) or 0
		sum = sum + b
	end
	for i = 157,500 do
		local b = block:byte(i) or 0
		sum = sum + b
	end
	return sum
end

local function nullterm(s)
	return s:match("^[^%z]*")
end

local function read_header_block(block)
	local header = {}
	header.name = nullterm(block:sub(1,100))
	header.mode = nullterm(block:sub(101,108)):gsub(" ", "")
	header.uid = octal_to_number(nullterm(block:sub(109,116)))
	header.gid = octal_to_number(nullterm(block:sub(117,124)))
	header.size = octal_to_number(nullterm(block:sub(125,136)))
	header.mtime = octal_to_number(nullterm(block:sub(137,148)))
	header.chksum = octal_to_number(nullterm(block:sub(149,156)))
	header.typeflag = get_typeflag(block:sub(157,157))
	header.linkname = nullterm(block:sub(158,257))
	header.magic = block:sub(258,263)
	header.version = block:sub(264,265)
	header.uname = nullterm(block:sub(266,297))
	header.gname = nullterm(block:sub(298,329))
	header.devmajor = octal_to_number(nullterm(block:sub(330,337)))
	header.devminor = octal_to_number(nullterm(block:sub(338,345)))
	header.prefix = block:sub(346,500)
	if not checksum_header(block) == header.chksum then
		return false, "Failed header checksum"
	end
	return header
end

local function untar_stream(tar_handle, destdir, verbose)
	assert(type(destdir) == "string")

	local long_name, long_link_name
	local ok, err

	local make_dir = function(a)
		if not fs.exists(a) then
			fs.makeDir(a)
		end
		return true
	end

	while true do
		local block
		repeat
			block = tar_handle:read(blocksize)
		until (not block) or checksum_header(block) > 256
		if not block then break end
		if #block < blocksize then
			ok, err = nil, "Invalid block size -- corrupted file?"
			break
		end
		local header
		header, err = read_header_block(block)
		if not header then
			ok = false
			break
		end

		local file_data = tar_handle:read(math.ceil(header.size / blocksize) * blocksize):sub(1,header.size)

		if header.typeflag == "long name" then
			long_name = nullterm(file_data)
		elseif header.typeflag == "long link name" then
			long_link_name = nullterm(file_data)
		else
			if long_name then
				header.name = long_name
				long_name = nil
			end
			if long_link_name then
				header.name = long_link_name
				long_link_name = nil
			end
		end
		local pathname = fs.combine(destdir, header.name)

		if header.typeflag == "directory" then
			ok, err = make_dir(pathname)
			if not ok then
				break
			end
		elseif header.typeflag == "file" then
			local dirname = fs.getDir(pathname)
			if dirname ~= "" then
				ok, err = make_dir(dirname)
				if not ok then
					break
				end
			end
			local file_handle
			if verbose then
				print(pathname)
			end
			file_handle, err = io.open(pathname, "wb")
			if not file_handle then
				ok = nil
				break
			end
			file_handle:write(file_data)
			file_handle:close()
		end
	end

	return ok, err
end

local function untar_string(str, destdir, verbose)
	local ctr = 1
	local len = #str
	local handle = {
		read = function(_, n)
			if ctr < len then
				local s = _sub(str, ctr, ctr + n - 1)
				ctr = ctr + n
				return s
			end
		end
	}
	return untar_stream(handle, destdir, verbose)
end

local function untar(filename, destdir, verbose)
	assert(type(filename) == "string")
	assert(type(destdir) == "string")

	local tar_handle = io.open(filename, "rb")
	if not tar_handle then return nil, "Error opening file "..filename end

	local ok, err = untar_stream(tar_handle, destdir, verbose)

	tar_handle:close()
	return ok, err
end

local function create_header_block(filename, abspath)
	local block = ('\0'):rep(blocksize)

	local function number_to_octal(n)
		return ('%o'):format(n)
	end

	local function ins(pos, istr)
		block = block:sub(1, pos - 1) .. istr .. block:sub(pos + #istr)
	end

	ins(1, filename) -- header
	ins(125, number_to_octal(fs.getSize(abspath)))
	ins(157, '0') -- typeflag

	ins(149, number_to_octal(checksum_header(block)))

	return block
end

local function tar_stream(tar_handle, root, files)
	if not files then
		files = { }
		local function recurse(rel)
			local abs = fs.combine(root, rel)
			for _,f in ipairs(fs.list(abs)) do
				local fullName = fs.combine(abs, f)
				if fs.isDir(fullName) then -- skip virtual dirs
					recurse(fs.combine(rel, f))
				else
					table.insert(files, fs.combine(rel, f))
				end
			end
		end
		recurse('')
	end

	for _, file in pairs(files) do
		local abs = fs.combine(root, file)
		local block = create_header_block(file, abs)
		tar_handle:write(block)
		local f = Util.readFile(abs, 'rb')
		tar_handle:write(f)
		local padding = #f % blocksize
		if padding > 0 then
			tar_handle:write(('\0'):rep(blocksize - padding))
		end
	end
end

local function tar_string(root, files)
	local t = { }
	local handle = {
		write = function(_, s)
			table.insert(t, s)
		end
	}
	tar_stream(handle, root, files)
	return table.concat(t)
end

-- the bare minimum for this program to untar
local function tar(filename, root, files)
	assert(type(filename) == "string")
	assert(type(root) == "string")

	local tar_handle = io.open(filename, "wb")
	if not tar_handle then return nil, "Error opening file "..filename end

	local ok, err = tar_stream(tar_handle, root, files)

	tar_handle:close()
	return ok, err
end

return {
	tar = tar,
	untar = untar,
	tar_string = tar_string,
	untar_string = untar_string,
}

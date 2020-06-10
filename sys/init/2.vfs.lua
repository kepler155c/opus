local fs = _G.fs

if fs.native then
	return
end

local Util = require('opus.util')

fs.native = Util.shallowCopy(fs)

local fstypes = { }
local nativefs = { }

for k,fn in pairs(fs) do
	if type(fn) == 'function' then
		nativefs[k] = function(_, ...)
			return fn(...)
		end
	end
end

function nativefs.resolve(_, dir)
	return dir
end

function nativefs.list(node, dir)
	local files
	if fs.native.isDir(dir) then
		files = fs.native.list(dir)
	end

	local function inList(l, e)
		for _,v in ipairs(l) do
			if v == e then
				return true
			end
		end
	end

	if dir == node.mountPoint and node.nodes then
		files = files or { }
		for k in pairs(node.nodes) do
			if not inList(files, k) then
				table.insert(files, k)
			end
		end
	end

	if not files then
		error('Not a directory', 2)
	end

	return files
end

function nativefs.getSize(node, dir, recursive)
	if recursive and fs.native.isDir(dir) then
		local function sum(dir)
			local total = 0
			local files = fs.native.list(dir)
			for _,f in ipairs(files) do
				local fullName = fs.combine(dir, f)
				if fs.native.isDir(fullName) then
					total = total + sum(fullName)
				else
					total = total + fs.native.getSize(fullName)
				end
			end
			return total
		end
		return sum(dir)
	end
	if node.mountPoint == dir and node.nodes then
		return 0
	end
	return fs.native.getSize(dir)
end

function nativefs.isDir(node, dir)
	if node.mountPoint == dir then
		return not not node.nodes
	end
	return fs.native.isDir(dir)
end

function nativefs.attributes(node, path)
	if node.mountPoint == path then
		return {
			created = node.created or os.epoch('utc'),
			modification = node.modification or os.epoch('utc'),
			isDir = not not node.nodes,
			size = node.size or 0,
		}
	end
	return fs.native.attributes(path)
end

function nativefs.exists(node, dir)
	if node.mountPoint == dir then
		return true
	end
	return fs.native.exists(dir)
end

function nativefs.getDrive(node, dir)
	if node.mountPoint == dir then
		return fs.native.getDrive(dir) or 'virt'
	end
	return fs.native.getDrive(dir)
end

function nativefs.delete(node, dir)
	if node.mountPoint == dir then
		fs.unmount(dir)
	else
		fs.native.delete(dir)
	end
end

fstypes.nativefs = nativefs
fs.nodes = {
	fs = nativefs,
	mountPoint = '',
	fstype = 'nativefs',
	nodes = { },
}

local function splitpath(path)
	local parts = { }
	for match in string.gmatch(path, "[^/]+") do
		table.insert(parts, match)
	end
	return parts
end

local function getNode(dir)
	if not dir then error('Invalid directory', 2) end
	local cd = fs.combine(dir, '')
	local parts = splitpath(cd)
	local node = fs.nodes

	for _,d in ipairs(parts) do
		if node.nodes and node.nodes[d] then
			node = node.nodes[d]
		else
			break
		end
	end

	return node
end

fs.getNode = getNode

local methods = { 'delete', 'getFreeSpace', 'exists', 'isDir', 'getSize',
	'isReadOnly', 'makeDir', 'getDrive', 'list', 'open', 'attributes' }

for _,m in pairs(methods) do
	fs[m] = function(dir, ...)
		dir = fs.combine(dir or '', '')
		local node = getNode(dir)
		return node.fs[m](node, dir, ...)
	end
end

-- if a link, return the source for this link
function fs.resolve(dir)
	local n = getNode(dir)
	return n.fs.resolve and n.fs.resolve(n, dir) or dir
end

function fs.complete(partial, dir, includeFiles, includeSlash)
	dir = fs.combine(dir, '')
	local node = getNode(dir)
	if node.fs.complete then
		return node.fs.complete(node, partial, dir, includeFiles, includeSlash)
	end
	return fs.native.complete(partial, dir, includeFiles, includeSlash)
end

local displayFlags = {
	urlfs  = 'U',
	linkfs = 'L',
	ramfs  = 'T',
	netfs  = 'N',
}

function fs.listEx(dir)
  dir = fs.combine(dir, '')
	local node = getNode(dir)
	if node.fs.listEx then
		return node.fs.listEx(node, dir)
	end

	local t = { }
	local files = node.fs.list(node, dir)

	for _,f in ipairs(files) do
		pcall(function()
			local fullName = fs.combine(dir, f)
			local n = fs.getNode(fullName)
			local file = {
				name = f,
				isDir = fs.isDir(fullName),
				isReadOnly = fs.isReadOnly(fullName),
				fstype = n.mountPoint == fullName and displayFlags[n.fstype],
			}
			if not file.isDir then
				file.size = fs.getSize(fullName)
			end
			table.insert(t, file)
		end)
	end
	return t
end

function fs.copy(s, t)
	if not s then error('copy: bad argument #1') end
	if not t then error('copy: bad argument #2') end
	local sp = getNode(s)
	local tp = getNode(t)
	if sp == tp and sp.fs.copy then
		return sp.fs.copy(sp, s, t)
	end

	if fs.exists(t) then
		error('File exists')
	end

	if fs.isDir(s) then
		fs.makeDir(t)
		local list = fs.list(s)
		for _,f in ipairs(list) do
			fs.copy(fs.combine(s, f), fs.combine(t, f))
		end

	else
		local sf = Util.readFile(s, 'rb')
		if not sf then
			error('No such file')
		end

		Util.writeFile(t, sf, 'wb')
	end
end

function fs.find(spec) -- not optimized
--  local node = getNode(spec)
--  local files = node.fs.find(node, spec)
	local files = { }
	-- method from https://github.com/N70/deltaOS/blob/dev/vfs

	-- REVISIT - see globbing in shellex package
	local function recurse_spec(results, path, spec)
		local segment = spec:match('([^/]*)'):gsub('/', '')
		local pattern = '^' .. segment:gsub("[%.%[%]%(%)%%%+%-%?%^%$]","%%%1"):gsub("%z","%%z"):gsub("%*","[^/]-") .. '$'
		if fs.isDir(path) then
			for _, file in ipairs(fs.list(path)) do
				if file:match(pattern) then
					local f = fs.combine(path, file)
					if spec == segment then
						table.insert(results, f)
					end
					if fs.isDir(f) then
						recurse_spec(results, f, spec:sub(#segment + 2))
					end
				end
			end
		end
	end
	recurse_spec(files, '', spec)
	table.sort(files)

	return files
end

function fs.move(s, t)
	local sp = getNode(s)
	local tp = getNode(t)
	if sp == tp and sp.fs.move then
		return sp.fs.move(sp, s, t)
	end
	fs.copy(s, t)
	fs.delete(s)
end

local function getfstype(fstype)
	local vfs = fstypes[fstype]
	if not vfs then
		vfs = require('opus.fs.' .. fstype)
		fs.registerType(fstype, vfs)
	end
	return vfs
end

function fs.mount(path, fstype, ...)
	local vfs = getfstype(fstype)
	if not vfs then
		error('Invalid file system type')
	end

	-- get the mount point for the path
	-- ie. if packages is mapped to disk/packages
	-- and a request to mount /packages/foo
	-- then use disk/packages/foo as the mountPoint
	path = fs.resolve(path)

	local node = vfs.mount(path, ...)
	if node then
		local parts = splitpath(path)
		local targetName = table.remove(parts, #parts)

		local tp = fs.nodes
		for _,d in ipairs(parts) do
			if not tp.nodes then
				tp.nodes = { }
			end
			if not tp.nodes[d] then
				tp.nodes[d] = Util.shallowCopy(tp)
				tp.nodes[d].nodes = { }
				tp.nodes[d].mountPoint = fs.combine(tp.mountPoint, d)
				tp.nodes[d].created = os.epoch('utc')
				tp.nodes[d].modification = os.epoch('utc')
			end
			tp = tp.nodes[d]
		end

		node.fs = vfs
		node.fstype = fstype
		node.created = node.created or os.epoch('utc')
		node.modification = node.modification or os.epoch('utc')
		if not targetName then
			node.mountPoint = ''
			fs.nodes = node
		else
			node.mountPoint = fs.combine(tp.mountPoint, targetName)
			tp.nodes[targetName] = node
		end
	end
	return node
end

function fs.loadTab(path)
	local mounts = Util.readFile(path)
	if mounts then
		for _,l in ipairs(Util.split(mounts)) do
			l = Util.trim(l)
			if #l > 0 and l:sub(1, 1) ~= '#' then
				local s, m = pcall(function()
					fs.mount(table.unpack(Util.matches(l)))
				end)
				if not s then
					_G.printError('Mount failed')
					_G.printError(l)
					_G.printError(m)
				end
			end
		end
	end
end

local function getNodeByParts(parts)
	local node = fs.nodes

	for _,d in ipairs(parts) do
		if not node.nodes[d] then
			return
		end
		node = node.nodes[d]
	end
	return node
end

function fs.unmount(path)
	local parts = splitpath(path)
	local targetName = table.remove(parts, #parts)

	local node = getNodeByParts(parts)

	if node and node.nodes[targetName] then
		node.nodes[targetName] = nil
	end
end

function fs.registerType(name, vfs)
	fstypes[name] = vfs
end

function fs.getTypes()
	return fstypes
end

function fs.restore()
	local native = fs.native
	Util.clear(fs)
	Util.merge(fs, native)
end
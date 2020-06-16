local Util   = require('opus.util')

local fs = _G.fs

local ramfs = { }

function ramfs.mount(_, nodeType)
	if nodeType == 'directory' then
		return {
			nodes = { },
			size = 0,
			created = os.epoch('utc'),
			modification = os.epoch('utc'),
		}
	elseif nodeType == 'file' then
		return {
			size = 0,
			created = os.epoch('utc'),
			modification = os.epoch('utc'),
		}
	end
	error('ramfs syntax: [directory, file]')
end

function ramfs.attributes(node)
	return {
		created = node.created,
		isDir = not not node.nodes,
		modification = node.modification,
		size = node.size,
	}
end

function ramfs.delete(node, dir)
	if node.mountPoint == dir then
		fs.unmount(node.mountPoint)
	end
end

function ramfs.exists(node, fn)
	return node.mountPoint == fn
end

function ramfs.getSize(node)
	return node.size
end

function ramfs.isReadOnly()
	return false
end

function ramfs.makeDir(_, dir)
	fs.mount(dir, 'ramfs', 'directory')
end

function ramfs.isDir(node, dir)
	if node.mountPoint == dir then
		return not not node.nodes
	end
end

function ramfs.getDrive()
	return 'ram'
end

function ramfs.getFreeSpace()
	return math.huge
end

function ramfs.list(node, dir)
	if node.nodes and node.mountPoint == dir then
		local files = { }
		for k in pairs(node.nodes) do
			table.insert(files, k)
		end
		return files
	end
	error('Not a directory')
end

function ramfs.open(node, fn, fl)
	local modes = Util.transpose { 'r', 'w', 'rb', 'wb', 'a' }
	if not modes[fl] then
		error('Unsupported mode')
	end

	if fl == 'a' then
		if node.mountPoint ~= fn then
			fl = 'w'
		else
			local c = type(node.contents) == 'table'
				and string.char(table.unpack(node.contents))
				or node.contents
				or ''

			return {
				write = function(str)
					c = c .. str
				end,
				writeLine = function(str)
					c = c .. str .. '\n'
				end,
				flush = function()
					node.contents = c
					node.size = #c
				end,
				close = function()
					node.contents = c
					node.size = #c
					c = nil
				end,
			}
		end
	end

	if fl == 'r' then
		if node.mountPoint ~= fn then
			return
		end

		local c = type(node.contents) == 'table'
			and string.char(table.unpack(node.contents))
			or node.contents

		local ctr = 0
		local lines
		return {
			read = function(n)
				n = n or 1
				if ctr >= node.size then
					return
				end
				local t = c:sub(ctr + 1, ctr + n)
				ctr = ctr + n
				return t
			end,
			readLine = function()
				if not lines then
					lines = Util.split(c)
				end
				ctr = ctr + 1
				return lines[ctr]
			end,
			readAll = function()
				return c
			end,
			close = function()
				lines = nil
			end,
		}
	elseif fl == 'w' then
		node = fs.mount(fn, 'ramfs', 'file')

		local c = ''
		return {
			write = function(str)
				c = c .. str
			end,
			writeLine = function(str)
				c = c .. str .. '\n'
			end,
			flush = function()
				node.contents = c
				node.size = #c
			end,
			close = function()
				node.contents = c
				node.size = #c
				c = nil
			end,
		}
	elseif fl == 'rb' then
		if node.mountPoint ~= fn or not node.contents then
			return
		end

		local c = node.contents
		if type(node.contents) == 'string' then
			c = { }
			for i = 1, node.size do
				c[i] = node.contents:sub(i, i):byte()
			end
		end

		local ctr = 0
		return {
			readAll = function()
				return string.char(table.unpack(c))
			end,
			read = function(n)
				if n and n > 1 and ctr < node.size then
					-- some programs open in rb, when it should have
					-- been opened in r - attempt to support multiple read
					-- if nils are present in data, this will fail
					local t = string.char(table.unpack(c, ctr + 1, ctr + n))
					ctr = ctr + n
					return t
				end
				ctr = ctr + 1
				return c[ctr]
			end,
			close = function()
			end,
		}

	elseif fl == 'wb' then
		node = fs.mount(fn, 'ramfs', 'file')

		local c = { }
		return {
			write = function(b)
				if type(b) == 'number' then
					table.insert(c, b)
				else
					for i = 1, #b do
						table.insert(c, b:sub(i, i):byte())
					end
				end
			end,
			flush = function()
				node.contents = c
				node.size = #c
			end,
			close = function()
				node.contents = c
				node.size = #c
				c = nil
			end,
		}
	end
end

return ramfs

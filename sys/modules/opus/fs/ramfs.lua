local Util   = require('opus.util')

local fs = _G.fs

local ramfs = { }

function ramfs.mount(_, nodeType)
	if nodeType == 'directory' then
		return {
			nodes = { },
			size = 0,
		}
	elseif nodeType == 'file' then
		return {
			size = 0,
		}
	end
	error('ramfs syntax: [directory, file]')
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

function ramfs.isDir(node)
	return not not node.nodes
end

function ramfs.getDrive()
	return 'ram'
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

	if fl ~= 'r' and fl ~= 'w' and fl ~= 'rb' and fl ~= 'wb' then
		error('Unsupported mode')
	end

	if fl == 'r' then
		if node.mountPoint ~= fn then
			return
		end

		local ctr = 0
		local lines
		return {
			readLine = function()
				if not lines then
					lines = Util.split(node.contents)
				end
				ctr = ctr + 1
				return lines[ctr]
			end,
			readAll = function()
				return node.contents
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

		local ctr = 0
		return {
			read = function()
				ctr = ctr + 1
				return node.contents[ctr]
			end,
			close = function()
			end,
		}

	elseif fl == 'wb' then
		node = fs.mount(fn, 'ramfs', 'file')

		local c = { }
		return {
			write = function(b)
				table.insert(c, b)
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

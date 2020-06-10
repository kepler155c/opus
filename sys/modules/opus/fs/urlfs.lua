--local rttp = require('rttp')
local Util = require('opus.util')

local fs = _G.fs

local urlfs = { }

function urlfs.mount(path, url, force)
	if not url then
		error('URL is required')
	end

	-- only mount if the file does not exist already
	if not fs.exists(path) or force then
		return {
			url = url,
			created = os.epoch('utc'),
			modification = os.epoch('utc'),
		}
	end
end

function urlfs.attributes(node, path)
	return path == node.mountPoint and {
		created = node.created,
		isDir = false,
		modification = node.modification,
		size = node.size or 0,
	}
end

function urlfs.delete(node, path)
	if path == node.mountPoint then
		fs.unmount(path)
	end
end

function urlfs.exists(node, path)
	return path == node.mountPoint
end

function urlfs.getSize(node, path)
	return path == node.mountPoint and node.size or 0
end

function urlfs.isReadOnly()
	return false
end

function urlfs.isDir()
	return false
end

function urlfs.getDrive()
	return 'url'
end

function urlfs.open(node, fn, fl)
	if fl == 'w' or fl == 'wb' then
		fs.delete(fn)
		return fs.open(fn, fl)
	end

	if fl ~= 'r' and fl ~= 'rb' then
		error('Unsupported mode')
	end

	local c = node.cache
	if not c then
		c = Util.httpGet(node.url)
		if c then
			node.cache = c
			node.size = #c
		end
	end

	if not c then
		return
	end

	local ctr = 0
	local lines

	if fl == 'r' then
		return {
			read = function()
                ctr = ctr + 1
                return c:sub(ctr, ctr)
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
	end
	return {
		readAll = function()
			return c
		end,
		read = function()
			ctr = ctr + 1
			return c:sub(ctr, ctr):byte()
		end,
		close = function()
			ctr = 0
		end,
	}
end

return urlfs

local Socket       = require('opus.socket')
local synchronized = require('opus.sync').sync

local fs = _G.fs

local netfs = { }

local function remoteCommand(node, msg)
	for _ = 1, 2 do
		if not node.socket then
			node.socket = Socket.connect(node.id, 139)
		end

		if not node.socket then
			error('netfs: Unable to establish connection to ' .. node.id)
			fs.unmount(node.mountPoint)
			return
		end

		local ret
		synchronized(node.socket, function()
			node.socket:write(msg)
			ret = node.socket:read(1)
		end)

		if ret then
			return ret.response
		end
		node.socket:close()
		node.socket = nil
	end
	error('netfs: Connection failed', 2)
end

local methods = { 'delete', 'exists', 'getFreeSpace', 'makeDir', 'list', 'listEx', 'attributes' }

local function resolve(node, dir)
	-- TODO: Wrong ! (does not support names with dashes)
	dir = dir:gsub(node.mountPoint, '', 1)
	return fs.combine(node.source, dir)
end

for _,m in pairs(methods) do
	netfs[m] = function(node, dir)
		dir = resolve(node, dir)

		return remoteCommand(node, {
			fn = m,
			args = { dir },
		})
	end
end

function netfs.mount(_, id, source)
	if not id or not tonumber(id) then
		error('ramfs syntax: computerId [directory]')
	end
	return {
		id = tonumber(id),
		nodes = { },
		source = source or '',
	}
end

function netfs.getDrive()
	return 'net'
end

function netfs.complete(node, partial, dir, includeFiles, includeSlash)
	dir = resolve(node, dir)

	return remoteCommand(node, {
		fn = 'complete',
		args = { partial, dir, includeFiles, includeSlash },
	})
end

function netfs.copy(node, s, t)
	s = resolve(node, s)
	t = resolve(node, t)

	return remoteCommand(node, {
		fn = 'copy',
		args = { s, t },
	})
end

function netfs.isDir(node, dir)
	if dir == node.mountPoint and node.source == '' then
		return true
	end
	return remoteCommand(node, {
		fn = 'isDir',
		args = { resolve(node, dir) },
	})
end

function netfs.isReadOnly(node, dir)
	if dir == node.mountPoint and node.source == '' then
		return false
	end
	return remoteCommand(node, {
		fn = 'isReadOnly',
		args = { resolve(node, dir) },
	})
end

function netfs.getSize(node, dir)
	if dir == node.mountPoint and node.source == '' then
		return 0
	end
	return remoteCommand(node, {
		fn = 'getSize',
		args = { resolve(node, dir) },
	})
end

function netfs.find(node, spec)
	spec = resolve(node, spec)
	local list = remoteCommand(node, {
		fn = 'find',
		args = { spec },
	})

	for k,f in ipairs(list) do
		list[k] = fs.combine(node.mountPoint, f)
	end

	return list
end

function netfs.move(node, s, t)
	s = resolve(node, s)
	t = resolve(node, t)

	return remoteCommand(node, {
		fn = 'move',
		args = { s, t },
	})
end

function netfs.open(node, fn, fl)
	fn = resolve(node, fn)

	local vfh = remoteCommand(node, {
		fn = 'open',
		args = { fn, fl },
	})

	if vfh then
		vfh.node = node
		for _,m in ipairs(vfh.methods) do
			vfh[m] = function(...)
				return remoteCommand(node, {
					fn = 'fileOp',
					args = { vfh.fileUid, m, ... },
				})
			end
		end
	end

	return vfh
end

return netfs

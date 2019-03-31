local Event  = require('event')
local Socket = require('socket')

local fs = _G.fs

local fileUid = 0
local fileHandles = { }

local function remoteOpen(fn, fl)
	local fh = fs.open(fn, fl)
	if fh then
		local methods = { 'close', 'write', 'writeLine', 'flush', 'read', 'readLine', 'readAll', }
		fileUid = fileUid + 1
		fileHandles[fileUid] = fh

		local vfh = {
			methods = { },
			fileUid = fileUid,
		}

		for _,m in ipairs(methods) do
			if fh[m] then
				table.insert(vfh.methods, m)
			end
		end
		return vfh
	end
end

local function remoteFileOperation(fileId, op, ...)
	local fh = fileHandles[fileId]
	if fh then
		return fh[op](...)
	end
end

local function sambaConnection(socket)
	while true do
		local msg = socket:read()
		if not msg then
			break
		end
		local fn = fs[msg.fn]
		if msg.fn == 'open' then
			fn = remoteOpen
		elseif msg.fn == 'fileOp' then
			fn = remoteFileOperation
		end
		local ret
		local s, m = pcall(function()
			ret = fn(unpack(msg.args))
		end)
		if not s and m then
			_G.printError('samba: ' .. m)
		end
		socket:write({ response = ret })
	end

	print('samba: Connection closed')
end

Event.addRoutine(function()
	print('samba: listening on port 139')

	while true do
		local socket = Socket.server(139)

		Event.addRoutine(function()
			print('samba: connection from ' .. socket.dhost)
			sambaConnection(socket)
			print('samba: closing connection to ' .. socket.dhost)
		end)
	end
end)

Event.on('network_attach', function(_, computer)
	fs.mount(fs.combine('network', computer.label), 'netfs', computer.id)
end)

Event.on('network_detach', function(_, computer)
	print('samba: detaching ' .. computer.label)
	fs.unmount(fs.combine('network', computer.label))
end)

local Crypto   = require('opus.crypto.chacha20')
local Event    = require('opus.event')
local Security = require('opus.security')
local Socket   = require('opus.socket')
local Util     = require('opus.util')

local function trustConnection(socket)
	local data = socket:read(2)
	if data then
		local password = Security.getPassword()
		if not password then
			socket:write({ msg = 'No password has been set' })
		else
			data = Crypto.decrypt(data, password)
			if data and data.pk and data.dh == socket.dhost then
				local trustList = Util.readTable('usr/.known_hosts') or { }
				trustList[data.dh] = Util.byteArrayToHex(data.pk)
				Util.writeTable('usr/.known_hosts', trustList)

				socket:write({ success = true, msg = 'Trust accepted' })
			else
				socket:write({ msg = 'Invalid password' })
			end
		end
	end
end

Event.addRoutine(function()
	print('trust: listening on port 19')

	while true do
		local socket = Socket.server(19)

		print('trust: connection from ' .. socket.dhost)

		local s, m = pcall(trustConnection, socket)
		socket:close()
		if not s and m then
			print('Trust error')
			_G.printError(m)
		end
	end
end)

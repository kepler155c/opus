local Crypto   = require('crypto')
local Event    = require('event')
local Security = require('security')
local Socket   = require('socket')
local Util     = require('util')

Event.addRoutine(function()

	print('trust: listening on port 19')
	while true do
		local socket = Socket.server(19)

		print('trust: connection from ' .. socket.dhost)

		local data = socket:read(2)
		if data then
			local password = Security.getPassword()
			if not password then
				socket:write({ msg = 'No password has been set' })
			else
				data = Crypto.decrypt(data, password)
				if data and data.pk and data.dh == socket.dhost then
					local trustList = Util.readTable('usr/.known_hosts') or { }
					trustList[data.dh] = data.pk
					Util.writeTable('usr/.known_hosts', trustList)

					socket:write({ success = true, msg = 'Trust accepted' })
				else
					socket:write({ msg = 'Invalid password' })
				end
			end
		end
		socket:close()
	end
end)

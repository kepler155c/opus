local Crypto   = require('opus.crypto.chacha20')
local Event    = require('opus.event')
local Security = require('opus.security')
local Socket   = require('opus.socket')
local Util     = require('opus.util')

local trustId = '01c3ba27fe01383a03a1785276d99df27c3edcef68fbf231ca'

local oneTimePassword -- nil by default

local function validateData(data, password, dhost)
	local s
	s, data = pcall(Crypto.decrypt, data, password)

	if s and data and type(data) == "table" and data.pk and data.dh == dhost then
		local trustList = Util.readTable('usr/.known_hosts') or { }
		trustList[data.dh] = data.pk
		Util.writeTable('usr/.known_hosts', trustList)
		return true
	else
		return false
	end
end

local function trustConnection(socket)
	local data = socket:read(2)
	if data then
		local password = Security.getPassword()
		if not password then
			socket:write({ msg = 'No password has been set' })
		else
			if validateData(data, password, socket.dhost) then
				print("Accepted trust from " .. socket.dhost)
				socket:write({ success = true, msg = 'Trust accepted' })
				return
			end

			if oneTimePassword then
				if validateData(data, oneTimePassword, socket.dhost) then
					print("Accepted trust from " .. socket.dhost .. "using one-time password")
					socket:write({ success = true, msg = 'Trust accepted - this one-time password will not be usable again' })
					oneTimePassword = nil -- Make sure nobody can use the one-time password again
					return
				end
			end

			socket:write({ msg = 'Invalid password' })
		end
	end
end

Event.addRoutine(function()
	print('trust: listening on port 19')

	while true do
		local socket = Socket.server(19, { identifier = trustId })

		print('trust: connection from ' .. socket.dhost)

		local s, m = pcall(trustConnection, socket)
		socket:close()
		if not s and m then
			print('Trust error')
			_G.printError(m)
		end
	end
end)

Event.addRoutine(function()
	while true do
		local _event, password = os.pullEvent("set_otp")

		oneTimePassword = password
		print("got new one-time password")
	end
end)
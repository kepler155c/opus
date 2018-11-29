local Crypto   = require('crypto')
local Logger   = require('logger')
local Security = require('security')
local Util     = require('util')

local device    = _G.device
local os        = _G.os

local socketClass = { }

function socketClass:read(timeout)
	local data, distance = _G.transport.read(self)
	if data then
		return data, distance
	end

	if not self.connected then
		Logger.log('socket', 'read: No connection')
		return
	end

	local timerId = os.startTimer(timeout or 5)

	while true do
		local e, id = os.pullEvent()

		if e == 'transport_' .. self.uid then
			data, distance = _G.transport.read(self)
			if data then
				os.cancelTimer(timerId)
				return data, distance
			end
			if not self.connected then
				break
			end

		elseif e == 'timer' and id == timerId then
			if timeout or not self.connected then
				break
			end
			timerId = os.startTimer(5)
			self:ping()
		end
	end
end

function socketClass:write(data)
	if self.connected then
		_G.transport.write(self, {
			type = 'DATA',
			seq = self.wseq,
			data = data,
		})
		return true
	end
end

function socketClass:ping()
	if self.connected then
		_G.transport.ping(self)
		return true
	end
end

function socketClass:close()
	if self.connected then
		Logger.log('socket', 'closing socket ' .. self.sport)
		self.transmit(self.dport, self.dhost, {
			type = 'DISC',
		})
		self.connected = false
	end
	device.wireless_modem.close(self.sport)
	_G.transport.close(self)
end

local Socket = { }

local function loopback(port, sport, msg)
	os.queueEvent('modem_message', 'loopback', port, sport, msg, 0)
end

local function newSocket(isLoopback)
	for _ = 16384, 32767 do
		local i = math.random(16384, 32767)
		if not device.wireless_modem.isOpen(i) then
			local socket = {
				shost = os.getComputerID(),
				sport = i,
				transmit = device.wireless_modem.transmit,
				wseq = math.random(100, 100000),
				rseq = math.random(100, 100000),
				timers = { },
				messages = { },
			}
			setmetatable(socket, { __index = socketClass })

			device.wireless_modem.open(socket.sport)

			if isLoopback then
				socket.transmit = loopback
			end
			return socket
		end
	end
	error('No ports available')
end

function Socket.connect(host, port)
	if not device.wireless_modem then
		return false, 'Wireless modem not found'
	end

	local socket = newSocket(host == os.getComputerID())
	socket.dhost = tonumber(host)
	Logger.log('socket', 'connecting to ' .. port)

	socket.transmit(port, socket.sport, {
		type = 'OPEN',
		shost = socket.shost,
		dhost = socket.dhost,
		t = Crypto.encrypt({ ts = os.time(), seq = socket.seq }, Security.getPublicKey()),
		rseq = socket.wseq,
		wseq = socket.rseq,
	})

	local timerId = os.startTimer(3)
	repeat
		local e, id, sport, dport, msg = os.pullEvent()
		if e == 'modem_message' and
			 sport == socket.sport and
			 type(msg) == 'table' and
			 msg.dhost == socket.shost then

			os.cancelTimer(timerId)

			if msg.type == 'CONN' then

				socket.dport = dport
				socket.connected = true
				Logger.log('socket', 'connection established to %d %d->%d',
															host, socket.sport, socket.dport)

				_G.transport.open(socket)

				return socket
			elseif msg.type == 'REJE' then
				return false, 'Password not set on target or not trusted'
			end
		end
	until e == 'timer' and id == timerId

	socket:close()

	return false, 'Connection timed out'
end

local function trusted(msg, port)
	if port == 19 or msg.shost == os.getComputerID() then
		-- no auth for trust server or loopback
		return true
	end

	if not Security.hasPassword() then
		-- no password has been set on this computer
		--return true
	end

	local trustList = Util.readTable('usr/.known_hosts') or { }
	local pubKey = trustList[msg.shost]

	if pubKey then
		local data = Crypto.decrypt(msg.t or '', pubKey)

		--local sharedKey = modexp(pubKey, exchange.secretKey, public.primeMod)
		return data.ts and tonumber(data.ts) and math.abs(os.time() - data.ts) < 24
	end
end

function Socket.server(port)
	device.wireless_modem.open(port)
	Logger.log('socket', 'Waiting for connections on port ' .. port)

	while true do
		local _, _, sport, dport, msg = os.pullEvent('modem_message')

		if sport == port and
			 msg and
			 type(msg) == 'table' and
			 msg.dhost == os.getComputerID() and
			 msg.type == 'OPEN' then

			local socket = newSocket(msg.shost == os.getComputerID())
			socket.dport = dport
			socket.dhost = msg.shost
			socket.wseq = msg.wseq
			socket.rseq = msg.rseq

			if trusted(msg, port) then
				socket.connected = true
				socket.transmit(socket.dport, socket.sport, {
					type = 'CONN',
					dhost = socket.dhost,
					shost = socket.shost,
				})
				Logger.log('socket', 'Connection established %d->%d', socket.sport, socket.dport)

				_G.transport.open(socket)
				return socket
			end

			socket.transmit(socket.dport, socket.sport, {
				type = 'REJE',
				dhost = socket.dhost,
				shost = socket.shost,
			})
			socket:close()
		end
	end
end

return Socket

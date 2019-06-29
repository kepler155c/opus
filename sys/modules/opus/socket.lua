local Crypto   = require('opus.crypto.chacha20')
local ECC      = require('opus.crypto.ecc')
local Security = require('opus.security')
local SHA      = require('opus.crypto.sha2')
local Util     = require('opus.util')

local device    = _G.device
local os        = _G.os

local socketClass = { }

function socketClass:read(timeout)
	local data, distance = _G.transport.read(self)
	if data then
		return data, distance
	end

	if not self.connected then
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

function socketClass:setupEncryption()
	self.sharedKey = ECC.exchange(self.privKey, self.remotePubKey)
	self.enckey  = SHA.pbkdf2(self.sharedKey, "1enc", 1)
	self.hmackey  = SHA.pbkdf2(self.sharedKey, "2hmac", 1)
	self.rseed  = SHA.pbkdf2(self.sharedKey, "3rseed", 1)
	self.wseed  = SHA.pbkdf2(self.sharedKey, "4sseed", 1)
end

function socketClass:close()
	if self.connected then
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
		return false, 'Wireless modem not found', 'NOMODEM'
	end

	local socket = newSocket(host == os.getComputerID())
	socket.dhost = tonumber(host)
	socket.privKey, socket.pubKey = Security.generateKeyPair()

	socket.transmit(port, socket.sport, {
		type = 'OPEN',
		shost = socket.shost,
		dhost = socket.dhost,
		rseq = socket.wseq,
		wseq = socket.rseq,
		t = Crypto.encrypt({
			ts = os.time(),
			seq = socket.seq,
			nts = os.epoch('utc'),
			pk = Util.byteArrayToHex(socket.pubKey),
		}, Security.getPublicKey()),
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
				socket.remotePubKey = Util.hexToByteArray(msg.pk)
				socket:setupEncryption()
				-- Logger.log('socket', 'connection established to %d %d->%d',
				--											host, socket.sport, socket.dport)
				_G.transport.open(socket)
				return socket

			elseif msg.type == 'NOPASS' then
				socket:close()
				return false, 'Password not set on target', 'NOPASS'

			elseif msg.type == 'REJE' then
				socket:close()
				return false, 'Trust not established', 'NOTRUST'
			end
		end
	until e == 'timer' and id == timerId

	socket:close()
	return false, 'Connection timed out', 'TIMEOUT'
end

local function trusted(socket, msg, port)
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

	if pubKey and msg.t then
		local data = Crypto.decrypt(msg.t, Util.hexToByteArray(pubKey))

		if data and data.nts then -- upgraded security
			if data.nts and tonumber(data.nts) and math.abs(os.epoch('utc') - data.nts) < 1024 then
				socket.remotePubKey = Util.hexToByteArray(data.pk)
			end
		end

		--local sharedKey = modexp(pubKey, exchange.secretKey, public.primeMod)
		return data and data.ts and tonumber(data.ts) and math.abs(os.time() - data.ts) < 24
	end
end

function Socket.server(port)
	device.wireless_modem.open(port)
	-- Logger.log('socket', 'Waiting for connections on port ' .. port)

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

			if not Security.hasPassword() then
				socket.transmit(socket.dport, socket.sport, {
					type = 'NOPASS',
					dhost = socket.dhost,
					shost = socket.shost,
				})
				socket:close()

			elseif trusted(socket, msg, port) then
				socket.connected = true
				socket.privKey, socket.pubKey = Security.generateKeyPair()
				socket:setupEncryption()
				socket.transmit(socket.dport, socket.sport, {
					type = 'CONN',
					dhost = socket.dhost,
					shost = socket.shost,
					pk = Util.byteArrayToHex(socket.pubKey),
				})

				-- Logger.log('socket', 'Connection established %d->%d', socket.sport, socket.dport)

				_G.transport.open(socket)
				return socket

			else
				socket.transmit(socket.dport, socket.sport, {
					type = 'REJE',
					dhost = socket.dhost,
					shost = socket.shost,
				})
				socket:close()
			end
		end
	end
end

return Socket

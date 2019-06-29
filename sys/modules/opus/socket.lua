local Crypto   = require('opus.crypto.chacha20')
local ECC      = require('opus.crypto.ecc')
local Security = require('opus.security')
local SHA      = require('opus.crypto.sha2')
local Util     = require('opus.util')

local device    = _G.device
local os        = _G.os
local network   = _G.network

local socketClass = { }

function socketClass:read(timeout)
	local data, distance = network.getTransport().read(self)
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
			data, distance = network.getTransport().read(self)
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
		network.getTransport().write(self, {
			type = 'DATA',
			seq = self.wseq,
			data = data,
		})
		return true
	end
end

function socketClass:ping()
	if self.connected then
		network.getTransport().ping(self)
		return true
	end
end

function socketClass:setupEncryption(x)
local timer = Util.timer()
	self.sharedKey = ECC.exchange(self.privKey, self.remotePubKey)
	self.enckey  = SHA.pbkdf2(self.sharedKey, "1enc", 1)
	self.hmackey  = SHA.pbkdf2(self.sharedKey, "2hmac", 1)
	self.rseq  = SHA.pbkdf2(self.sharedKey, x and "3rseed" or "4sseed", 1):toHex()
	self.wseq  = SHA.pbkdf2(self.sharedKey, x and "4sseed" or "3rseed", 1):toHex()
_syslog('shared in ' .. timer())
end

function socketClass:close()
	if self.connected then
		self.transmit(self.dport, self.dhost, {
			type = 'DISC',
			seq = self.wseq,
		})
		self.connected = false
	end
	device.wireless_modem.close(self.sport)
	network.getTransport().close(self)
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

function Socket.connect(host, port, options)
	if not device.wireless_modem then
		return false, 'Wireless modem not found', 'NOMODEM'
	end
local timer = Util.timer()
	local socket = newSocket(host == os.getComputerID())
	socket.dhost = tonumber(host)
	socket.privKey, socket.pubKey = network.getKeyPair()
	local identifier = options and options.identifier or Security.getIdentifier()

	socket.transmit(port, socket.sport, {
		type = 'OPEN',
		shost = socket.shost,
		dhost = socket.dhost,
		t = Crypto.encrypt({ -- this is not that much data...
			ts = os.epoch('utc'),
			pk = Util.byteArrayToHex(socket.pubKey),
		}, Util.hexToByteArray(identifier)),
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
				socket:setupEncryption(true)
				-- Logger.log('socket', 'connection established to %d %d->%d',
				--											host, socket.sport, socket.dport)
				network.getTransport().open(socket)
_syslog('connection in ' .. timer())
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

local function trusted(socket, msg, options)
	local function getIdentifier()
		local trustList = Util.readTable('usr/.known_hosts') or { }
		return trustList[msg.shost]
	end

	local identifier = options and options.identifier or getIdentifier()

	if identifier and msg.t and type(msg.t) == 'table' then
		local data = Crypto.decrypt(msg.t, Util.hexToByteArray(identifier))

		if data and data.ts and tonumber(data.ts) then
_G._syslog('time diff ' .. math.abs(os.epoch('utc') - data.ts))
			if math.abs(os.epoch('utc') - data.ts) < 4096 then
				socket.remotePubKey = Util.hexToByteArray(data.pk)
				socket.privKey, socket.pubKey = network.getKeyPair()
				socket:setupEncryption()
				return true
			end
		end
	end
end

function Socket.server(port, options)
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
			socket.options = options

			if not Security.hasPassword() then
				socket.transmit(socket.dport, socket.sport, {
					type = 'NOPASS',
					dhost = socket.dhost,
					shost = socket.shost,
				})
				socket:close()

			elseif trusted(socket, msg, options) then
				socket.connected = true
				socket.transmit(socket.dport, socket.sport, {
					type = 'CONN',
					dhost = socket.dhost,
					shost = socket.shost,
					pk = Util.byteArrayToHex(socket.pubKey),
				})

				-- Logger.log('socket', 'Connection established %d->%d', socket.sport, socket.dport)

				network.getTransport().open(socket)
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

--[[
	Low level socket protocol implementation.

	* sequencing
	* background read buffering
]]--

local Crypto = require('opus.crypto.chacha20')
local Event  = require('opus.event')

local network = _G.network
local os = _G.os

local computerId = os.getComputerID()
local transport = {
	timers  = { },
	sockets = { },
	encryptQueue = { },
	UID = 0,
}

getmetatable(network).__index.getTransport = function()
	return transport
end

function transport.open(socket)
	transport.UID = transport.UID + 1

	transport.sockets[socket.sport] = socket
	socket.activityTimer = os.clock()
	socket.uid = transport.UID
end

function transport.read(socket)
	local data = table.remove(socket.messages, 1)
	if data then
		if socket.options.ENCRYPT then
			return table.unpack(Crypto.decrypt(data[1], socket.enckey)), data[2]
		end
		return table.unpack(data)
	end
end

function transport.write(socket, msg)
	if socket.options.ENCRYPT then
		if #transport.encryptQueue == 0 then
			os.queueEvent('transport_encrypt')
		end
		table.insert(transport.encryptQueue, { socket.sport, msg })
	else
		socket.transmit(socket.dport, socket.dhost, msg)
	end
	socket.wseq = socket.wrng:nextInt(5)
end

function transport.ping(socket)
	if os.clock() - socket.activityTimer > 10 then
		socket.activityTimer = os.clock()
		socket.transmit(socket.dport, socket.dhost, {
				type = 'PING',
				seq = -1,
			})

		local timerId = os.startTimer(3)
		transport.timers[timerId] = socket
		socket.timers[-1] = timerId
	end
end

function transport.close(socket)
	transport.sockets[socket.sport] = nil
end

Event.on('transport_encrypt', function()
	while #transport.encryptQueue > 0 do
		local entry = table.remove(transport.encryptQueue, 1)
		local socket = transport.sockets[entry[1]]

		if socket and socket.connected then
			local msg = entry[2]
			msg.data = Crypto.encrypt({ msg.data }, socket.enckey)
			socket.transmit(socket.dport, socket.dhost, msg)
		end
	end
end)

Event.on('timer', function(_, timerId)
	local socket = transport.timers[timerId]

	if socket and socket.connected then
		print('transport timeout - closing socket ' .. socket.sport)
		socket:close()
		transport.timers[timerId] = nil
	end
end)

Event.on('modem_message', function(_, _, dport, dhost, msg, distance)
	if dhost == computerId and type(msg) == 'table' then
		local socket = transport.sockets[dport]
		if socket and socket.connected then

			if socket.co and coroutine.status(socket.co) == 'dead' then
				_G._syslog('socket coroutine dead')
				socket:close()

			elseif msg.type == 'DISC' then
				-- received disconnect from other end
				if msg.seq == socket.rseq then
					if socket.connected then
						os.queueEvent('transport_' .. socket.uid)
					end
					socket.connected = false
					socket:close()
				end

			elseif msg.type == 'ACK' then
				local ackTimerId = socket.timers[msg.seq]
				if ackTimerId then
					os.cancelTimer(ackTimerId)
					socket.timers[msg.seq] = nil
					socket.activityTimer = os.clock()
					transport.timers[ackTimerId] = nil
				end

			elseif msg.type == 'PING' then
				socket.activityTimer = os.clock()
				socket.transmit(socket.dport, socket.dhost, {
					type = 'ACK',
					seq = msg.seq,
				})

			elseif msg.type == 'DATA' and msg.data then
				if msg.seq ~= socket.rseq then
					print('transport seq error ' .. socket.sport)
					_syslog(msg.data)
					_syslog('expected ' .. socket.rseq)
					_syslog('got ' .. msg.seq)
				else
					socket.activityTimer = os.clock()
					socket.rseq = socket.rrng:nextInt(5)

					table.insert(socket.messages, { msg.data, distance })

					if not socket.messages[2] then  -- table size is 1
						os.queueEvent('transport_' .. socket.uid)
					end
				end
			end
		end
	end
end)

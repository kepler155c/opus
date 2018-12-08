--[[
	Low level socket protocol implementation.

	* sequencing
	* background read buffering
]]--

local Event = require('event')

local os = _G.os

local computerId = os.getComputerID()
local transport = {
	timers  = { },
	sockets = { },
	UID = 0,
}
_G.transport = transport

function transport.open(socket)
	transport.UID = transport.UID + 1

	transport.sockets[socket.sport] = socket
	socket.activityTimer = os.clock()
	socket.uid = transport.UID
end

function transport.read(socket)
	local data = table.remove(socket.messages, 1)
	if data then
		return unpack(data)
	end
end

function transport.write(socket, data)
	--_debug('>> ' .. Util.tostring({ type = 'DATA', seq = socket.wseq }))
	socket.transmit(socket.dport, socket.dhost, data)

	--local timerId = os.startTimer(3)

	--transport.timers[timerId] = socket
	--socket.timers[socket.wseq] = timerId

	socket.wseq = socket.wseq + 1
end

function transport.ping(socket)
	--_debug('>> ' .. Util.tostring({ type = 'DATA', seq = socket.wseq }))
	if os.clock() - socket.activityTimer > 10 then
		socket.activityTimer = os.clock()
		socket.transmit(socket.dport, socket.dhost, {
				type = 'PING',
				seq = -1,
			})

		local timerId = os.startTimer(5)
		transport.timers[timerId] = socket
		socket.timers[-1] = timerId
	end
end

function transport.close(socket)
	transport.sockets[socket.sport] = nil
end

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

			--if msg.type then _debug('<< ' .. Util.tostring(msg)) end
			if socket.co and coroutine.status(socket.co) == 'dead' then
				_G._debug('socket coroutine dead')
				socket:close()

			elseif msg.type == 'DISC' then
				-- received disconnect from other end
				if socket.connected then
					os.queueEvent('transport_' .. socket.uid)
				end
				socket.connected = false
				socket:close()

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
				socket.activityTimer = os.clock()
				if msg.seq ~= socket.rseq then
					print('transport seq error - closing socket ' .. socket.sport)
					_debug(msg.data)
					_debug('current ' .. socket.rseq)
					_debug('expected ' .. msg.seq)
--					socket:close()
--					os.queueEvent('transport_' .. socket.uid)
				else
					socket.rseq = socket.rseq + 1
					table.insert(socket.messages, { msg.data, distance })

					-- use resume instead ??
					if not socket.messages[2] then  -- table size is 1
						os.queueEvent('transport_' .. socket.uid)
					end

					--_debug('>> ' .. Util.tostring({ type = 'ACK', seq = msg.seq }))
					--socket.transmit(socket.dport, socket.dhost, {
					--  type = 'ACK',
					--  seq = msg.seq,
					--})
				end
			end
		end
	end
end)

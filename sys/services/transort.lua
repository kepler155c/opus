--[[
  Low level socket protocol implementation.

  * sequencing
  * write acknowledgements
  * background read buffering
]]--

multishell.setTitle(multishell.getCurrent(), 'Net transport')

local computerId = os.getComputerID()

_G.transport = {
  timers  = { },
  sockets = { },
}

function transport.open(socket)
  transport.sockets[socket.sport] = socket
end

function transport.read(socket)
  local data = table.remove(socket.messages, 1)
  if data then
    return unpack(data)
  end
end

function transport.write(socket, data)

  --debug('>> ' .. Util.tostring({ type = 'DATA', seq = socket.wseq }))
  socket.transmit(socket.dport, socket.dhost, data)

  local timerId = os.startTimer(2)

  transport.timers[timerId] = socket
  socket.timers[socket.wseq] = timerId

  socket.wseq = socket.wseq + 1
end

function transport.close(socket)
  transport.sockets[socket.sport] = nil
end

print('Net transport started')

while true do
  local e, timerId, dport, dhost, msg, distance = os.pullEvent()

  if e == 'timer' then
    local socket = transport.timers[timerId]
    if socket and socket.connected then
      socket:close()
      transport.timers[timerId] = nil
    end

  elseif e == 'modem_message' and dhost == computerId and msg then
    local socket = transport.sockets[dport]
    if socket and socket.connected then

      --if msg.type then debug('<< ' .. Util.tostring(msg)) end

      if msg.type == 'DISC' then
        -- received disconnect from other end
        socket.connected = false
        socket:close()

      elseif msg.type == 'ACK' then
        local timerId = socket.timers[msg.seq]

        os.cancelTimer(timerId)
        socket.timers[msg.seq] = nil
        transport.timers[timerId] = nil

      elseif msg.type == 'DATA' and msg.data then
        if msg.seq ~= socket.rseq then
          socket:close()
        else
          socket.rseq = socket.rseq + 1
          table.insert(socket.messages, { msg.data, distance })

          -- use resume instead ??
          if not socket.messages[2] then  -- table size is 1
            os.queueEvent('transport_' .. dport)
          end

          --debug('>> ' .. Util.tostring({ type = 'ACK', seq = msg.seq }))
          socket.transmit(socket.dport, socket.dhost, {
            type = 'ACK',
            seq = msg.seq,
          })
        end
      end
    end
  end
end

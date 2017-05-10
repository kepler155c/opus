local Logger = require('logger')
local Crypto = require('crypto')

local socketClass = { }

local exchange = {
  base = 11,
  primeMod = 625210769
}

local function modexp(base, exponent, modulo)
  local remainder = base

  for i = 1, exponent-1 do
    remainder = remainder * remainder
    if remainder >= modulo then
      remainder = remainder % modulo
    end
  end

  return remainder
end

exchange.secretKey = os.getSecretKey()
exchange.publicKey = modexp(exchange.base, exchange.secretKey, exchange.primeMod)

function socketClass:read(timeout)

  if not self.connected then
    Logger.log('socket', 'read: No connection')
    return
  end

  local data, distance = transport.read(self)
  if data then
    return data, distance
  end

  local timerId = os.startTimer(timeout or 5)

  while true do
    local e, id = os.pullEvent()

    if e == 'transport_' .. self.dport then

      data, distance = transport.read(self)
      if data then
        os.cancelTimer(timerId)
        return data, distance
      end

    elseif e == 'timer' and id == timerId then
      if timeout or not self.connected then
        break
      end
      timerId = os.startTimer(5)
    end
  end
end

function socketClass:write(data)
  if not self.connected then
    Logger.log('socket', 'write: No connection')
    return false
  end
  transport.write(self, {
    type = 'DATA',
    seq = self.wseq,
    data = data,
  })
  return true
end

function socketClass:ping()
  if not self.connected then
    Logger.log('socket', 'ping: No connection')
    return false
  end
  transport.write(self, {
    type = 'PING',
    seq = self.wseq,
    data = data,
  })
  return true
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
  transport.close(self)
end

local Socket = { }

local function loopback(port, sport, msg)
  os.queueEvent('modem_message', 'loopback', port, sport, msg, 0)
end

local function newSocket(isLoopback)
  for i = 16384, 32767 do
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

  local socket = newSocket(host == os.getComputerID())
  socket.dhost = host
  Logger.log('socket', 'connecting to ' .. port)

  socket.transmit(port, socket.sport, {
    type = 'OPEN',
    shost = socket.shost,
    dhost = socket.dhost,
    t = Crypto.encrypt({ ts = os.time(), seq = socket.seq }, exchange.publicKey),
    rseq = socket.wseq,
    wseq = socket.rseq,
  })

  local timerId = os.startTimer(3)
  repeat
    local e, id, sport, dport, msg = os.pullEvent()
    if e == 'modem_message' and
       sport == socket.sport and
       msg.dhost == socket.shost and
       msg.type == 'CONN' then

      socket.dport = dport
      socket.connected = true
      Logger.log('socket', 'connection established to %d %d->%d',
                            host, socket.sport, socket.dport)

      os.cancelTimer(timerId)

      transport.open(socket)

      return socket
    end
  until e == 'timer' and id == timerId

  socket:close()
end

function trusted(msg, port)

  if port == 19 or msg.shost == os.getComputerID() then
    -- no auth for trust server or loopback
    return true
  end

  local trustList = Util.readTable('.known_hosts') or { }
  local pubKey = trustList[msg.shost]

  if pubKey then
    local data = Crypto.decrypt(msg.t or '', pubKey)

    --local sharedKey = modexp(pubKey, exchange.secretKey, public.primeMod)
    return data.ts and tonumber(data.ts) and math.abs(os.time() - data.ts) < 1
  end
end

function Socket.server(port)

  device.wireless_modem.open(port)
  Logger.log('socket', 'Waiting for connections on port ' .. port)

  while true do
    local e, _, sport, dport, msg = os.pullEvent('modem_message')

    if sport == port and
       msg and
       msg.dhost == os.getComputerID() and
       msg.type == 'OPEN' then

      if trusted(msg, port) then
        local socket = newSocket(msg.shost == os.getComputerID())
        socket.dport = dport
        socket.dhost = msg.shost
        socket.connected = true
        socket.wseq = msg.wseq
        socket.rseq = msg.rseq
        socket.transmit(socket.dport, socket.sport, {
          type = 'CONN',
          dhost = socket.dhost,
          shost = socket.shost,
        })
        Logger.log('socket', 'Connection established %d->%d', socket.sport, socket.dport)

        transport.open(socket)
        return socket
      end
    end
  end
end

return Socket

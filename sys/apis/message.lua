local Event = require('event')
local Logger = require('logger')

local Message = { }

local messageHandlers = {}

function Message.enable()
  if not device.wireless_modem.isOpen(os.getComputerID()) then
    device.wireless_modem.open(os.getComputerID())
  end
  if not device.wireless_modem.isOpen(60000) then
    device.wireless_modem.open(60000)
  end
end

if device and device.wireless_modem then
  Message.enable()
end

Event.on('device_attach', function(event, deviceName)
  if deviceName == 'wireless_modem' then
    Message.enable()
  end
end)

function Message.addHandler(type, f)
  table.insert(messageHandlers, {
    type = type,
    f = f,
    enabled = true
  })
end

function Message.removeHandler(h)
  for k,v in pairs(messageHandlers) do
	if v == h then
      messageHandlers[k] = nil
      break
    end
  end
end

Event.on('modem_message',
  function(event, side, sendChannel, replyChannel, msg, distance)
    if msg and msg.type then -- filter out messages from other systems
      local id = replyChannel
      Logger.log('modem_receive', { id, msg.type })
      --Logger.log('modem_receive', msg.contents)
      for k,h in pairs(messageHandlers) do
        if h.type == msg.type then
-- should provide msg.contents instead of message - type is already known
          h.f(h, id, msg, distance)
        end
      end
    end
  end
)

function Message.send(id, msgType, contents)
  if not device.wireless_modem then
    error('No modem attached', 2)
  end

  if id then
    Logger.log('modem_send', { tostring(id), msgType })
    device.wireless_modem.transmit(id, os.getComputerID(), {
      type = msgType, contents = contents
    })
  else
    Logger.log('modem_send', { 'broadcast', msgType })
    device.wireless_modem.transmit(60000, os.getComputerID(), {
      type = msgType, contents = contents
    })
  end
end

function Message.broadcast(t, contents)
  if not device.wireless_modem then
    error('No modem attached', 2)
  end

  Message.send(nil, t, contents)
--  Logger.log('rednet_send', { 'broadcast', t })
--  rednet.broadcast({ type = t, contents = contents })
end

function Message.waitForMessage(msgType, timeout, fromId)
  local timerId = os.startTimer(timeout)
  repeat
    local e, side, _id, id, msg, distance = os.pullEvent()
    if e == 'modem_message' then
      if msg and msg.type and msg.type == msgType then
        if not fromId or id == fromId then
          return e, id, msg, distance
        end
      end 
    end
  until e == 'timer' and side == timerId
end

function Message.enableWirelessLogging()
  Logger.setWirelessLogging()
end

return Message
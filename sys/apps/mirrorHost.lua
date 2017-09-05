requireInjector(getfenv(1))

local Event  = require('event')
local Logger = require('logger')
local Socket = require('socket')

Logger.setScreenLogging()

local args = { ... }
local mon = device[args[1] or 'monitor']

if not mon then
  error('Monitor not attached')
end

mon.setBackgroundColor(colors.black)
mon.clear()

while true do
  local socket = Socket.server(5901)

  print('mirror: connection from ' .. socket.dhost)

  Event.addRoutine(function()
    while true do
      local data = socket:read()
      if not data then
        break
      end
      for _,v in ipairs(data) do
        mon[v.f](unpack(v.args))
      end
    end
  end)

  -- ensure socket is connected
  Event.onInterval(3, function(h)
    if not socket:ping() then
      Event.off(h)
    end
  end)

  while true do
    Event.pullEvent()
    if not socket.connected then
      break
    end
  end

  print('connection lost')

  socket:close()
end

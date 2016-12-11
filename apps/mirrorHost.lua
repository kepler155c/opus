require = requireInjector(getfenv(1))
local Socket = require('socket')
local Logger = require('logger')
local process = require('process')

Logger.setScreenLogging()

local args = { ... }
local mon = device[args[1] or 'monitor']

if not mon then
  error('Monitor not attached')
end

mon.setBackgroundColor(colors.black)
mon.clear()

while true do
  local socket = Socket.server(5901, true)

  print('mirror: connection from ' .. socket.dhost)

  local updateThread = process:newThread('updateThread', function()
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

  while true do
    process:pullEvent('modem_message')
    if updateThread:isDead() then
      break
    end
  end

  print('connection lost')

  socket:close()
end

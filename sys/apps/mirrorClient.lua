requireInjector(getfenv(1))

local Event    = require('event')
local Logger   = require('logger')
local Socket   = require('socket')
local Terminal = require('terminal')
local Util     = require('util')

Logger.setScreenLogging()

local remoteId
local args = { ... }
if #args == 1 then
  remoteId = tonumber(args[1])
else
  print('Enter host ID')
  remoteId = tonumber(read())
end

if not remoteId then
  error('Syntax: mirrorClient <host ID>')
end

local function wrapTerm(socket)
  local methods = { 'blit', 'clear', 'clearLine', 'setCursorPos', 'write',
                    'setTextColor', 'setTextColour', 'setBackgroundColor',
                    'setBackgroundColour', 'scroll', 'setCursorBlink', }

  socket.term = multishell.term
  socket.oldTerm = Util.shallowCopy(socket.term)

  for _,k in pairs(methods) do
    socket.term[k] = function(...)
      if not socket.queue then
        socket.queue = { }
        Event.onTimeout(0, function()
          if socket.queue then
            socket:write(socket.queue)
            socket.queue = nil
          end
        end)
      end
      table.insert(socket.queue, {
        f = k,
        args = { ... },
      })
      socket.oldTerm[k](...)
    end
  end
end

while true do
  print('connecting...')
  local socket

  while true do
    socket = Socket.connect(remoteId, 5901)
    if socket then
      break
    end
    os.sleep(3)
  end

  print('connected')

  wrapTerm(socket)

  os.queueEvent('term_resize')

  while true do
    local e = Event.pullEvent()
    if e[1] == 'terminate' then
    	break
    end
    if not socket.connected then
      break
    end
  end

  for k,v in pairs(socket.oldTerm) do
    socket.term[k] = v
  end

  socket:close()

end

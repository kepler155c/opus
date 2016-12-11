require = requireInjector(getfenv(1))
local Socket = require('socket')
local Terminal = require('terminal')
local Logger = require('logger')
local process = require('process')

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
  error('Syntax: telnet <host ID>')
end

print('connecting...')
local socket

for i = 1,3 do
  socket = Socket.connect(remoteId, 5901)
  if socket then
    break
  end
  os.sleep(3)
end

if not socket then
  error('Unable to connect to ' .. remoteId .. ' on port 5901')
end

print('connected')

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
        os.queueEvent('mirror_flush')
      end
      table.insert(socket.queue, {
        f = k,
        args = { ... },
      })
      socket.oldTerm[k](...)
    end
  end
end

wrapTerm(socket)

os.queueEvent('term_resize')

while true do
  local e = process:pullEvent('mirror_flush')
  if e == 'terminate' then
  	break
  end
  if not socket.connected then
    break
  end
  if socket.queue then
    socket:write(socket.queue)
    socket.queue = nil
  end
end

for k,v in pairs(socket.oldTerm) do
  socket.term[k] = v
end

socket:close()

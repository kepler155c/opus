local Socket = require('socket')
local Event  = require('event')

local function wrapTerm(socket, termInfo)
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
          socket:write(socket.queue)
          socket.queue = nil
        end)
      end
      table.insert(socket.queue, {
        f = k,
        args = { ... },
      })
      socket.oldTerm[k](...)
    end
  end

  socket.term.getSize = function()
    return termInfo.width, termInfo.height
  end
end

local function vncHost(socket, termInfo)

  wrapTerm(socket, termInfo)

  os.queueEvent('term_resize')

  while true do
    local data = socket:read()
    if not data then
      print('vnc: closing connection to ' .. socket.dhost)
      break
    end

    if data.type == 'shellRemote' then
      os.queueEvent(unpack(data.event))
    end
  end

  for k,v in pairs(socket.oldTerm) do
    socket.term[k] = v
  end
  os.queueEvent('term_resize')
end

Event.addRoutine(function()

  print('vnc: listening on port 5900')

  while true do
    local socket = Socket.server(5900)

    print('vnc: connection from ' .. socket.dhost)

    local termInfo = socket:read(5)
    if termInfo then
      -- no new process - only 1 connection allowed
      -- due to term size issues
      vncHost(socket, termInfo) 
    else
      socket:close()
    end
  end
end)

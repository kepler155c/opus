local Event  = require('event')
local Socket = require('socket')
local Util   = require('util')

local multishell = _ENV.multishell
local os         = _G.os
local term       = _G.term

local function telnetHost(socket)
  _G.requireInjector()

  local Event = require('event')

  local methods = { 'clear', 'clearLine', 'setCursorPos', 'write', 'blit',
                    'setTextColor', 'setTextColour', 'setBackgroundColor',
                    'setBackgroundColour', 'scroll', 'setCursorBlink', }

  local termInfo = socket:read(5)
  if not termInfo then
    _G.printtError('read failed')
    return
  end

  socket.term = term.current()
  local oldWindow = Util.shallowCopy(socket.term)

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
      oldWindow[k](...)
    end
  end

  socket.term.getSize = function()
    return termInfo.width, termInfo.height
  end

  local shellThread = Event.addRoutine(function()
    os.run(_ENV, 'sys/apps/shell')
    Event.exitPullEvents()
  end)

  Event.addRoutine(function()
    while true do
      local data = socket:read()
      if not data then
        Event.exitPullEvents()
        break
      end
      shellThread:resume(table.unpack(data))
    end
  end)

  Event.pullEvents()

  socket:close()
  shellThread:terminate()
end

Event.addRoutine(function()
  print('telnet: listening on port 23')
  while true do
    local socket = Socket.server(23)

    print('telnet: connection from ' .. socket.dhost)

    multishell.openTab({
      fn = telnetHost,
      args = { socket },
      title = 'Telnet Client',
      hidden = true,
    })
  end
end)

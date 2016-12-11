local Socket = require('socket')
local process = require('process')

local function wrapTerm(socket, termInfo)
  local methods = { 'clear', 'clearLine', 'setCursorPos', 'write', 'blit',
                    'setTextColor', 'setTextColour', 'setBackgroundColor',
                    'setBackgroundColour', 'scroll', 'setCursorBlink', }

  socket.term = term.current()
  local oldWindow = Util.shallowCopy(socket.term)

  for _,k in pairs(methods) do
    socket.term[k] = function(...)
      if not socket.queue then
        socket.queue = { }
        os.startTimer(0)
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
end

local function telnetHost(socket, termInfo)

  require = requireInjector(getfenv(1))
  local process = require('process')

  wrapTerm(socket, termInfo)

  local shellThread = process:newThread('shell_wrapper', function()
    os.run(getfenv(1), '/apps/shell')
    socket:close()
  end)

  local queueThread = process:newThread('telnet_read', function()
    while true do
      local data = socket:read()
      if not data then
        break
      end

      if data.type == 'shellRemote' then
        local event = table.remove(data.event, 1)

        shellThread:resume(event, unpack(data.event))
      end
    end
  end)

  while true do
    local e = process:pullEvent('timer')

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

  socket:close()
  process:threadEvent('terminate')
end

process:newThread('telnet_server', function()

  print('telnet: listening on port 23')
  while true do
    local socket = Socket.server(23)

    print('telnet: connection from ' .. socket.dhost)

    local termInfo = socket:read(5)
    if termInfo then
      multishell.openTab({
        fn = telnetHost,
        args = { socket, termInfo },
        env = getfenv(1),
        title = 'Telnet Client',
        hidden = true,
      })
    end
  end
end)

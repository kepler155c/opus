local Socket = require('socket')
local process = require('process')
local Crypto = require('crypto')

process:newThread('trust_server', function()

  print('trust: listening on port 19')
  while true do
    local socket = Socket.server(19)

    print('trust: connection from ' .. socket.dhost)

    local data = socket:read(2)
    if data then
      local password = os.getPassword()
      if not password then
        socket:write('No password has been set')
      else
        data = Crypto.decrypt(data, password)
        if data and data.pk and data.dh then
          local trustList = Util.readTable('.known_hosts') or { }
          trustList[data.dh] = data.pk
          Util.writeTable('.known_hosts', trustList)

          socket:write('Trust accepted')
        else
          socket:write('Invalid password')
        end
      end
    end
    socket:close()
  end
end)

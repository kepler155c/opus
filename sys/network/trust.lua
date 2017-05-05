local Socket = require('socket')
local process = require('process')

process:newThread('trust_server', function()

  print('trust: listening on port 19')
  while true do
    local socket = Socket.server(19)

    print('trust: connection from ' .. socket.dhost)

    local data = socket:read(2)
    if data then
      if os.verifyPassword(data.password) then
        local trustList = Util.readTable('.known_hosts') or { }
        trustList[socket.dhost] = data.publicKey
        Util.writeTable('.known_hosts', trustList)

        socket:write('Trust accepted')
      else
        socket:write('Invalid password or password is not set')
      end
    end
    socket:close()
  end
end)

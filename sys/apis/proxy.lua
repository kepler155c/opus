local Socket  = require('socket')

local Proxy = { }

function Proxy.create(remoteId, uri)
  local socket, msg = Socket.connect(remoteId, 188)

  if not socket then
		error(msg)
	end

  socket.co = coroutine.running()

	socket:write(uri)
	local methods = socket:read(2) or error('Timed out')

	local hijack = { }
	for _,method in pairs(methods) do
		hijack[method] = function(...)
			socket:write({ method, ... })
			local resp = socket:read()
			if not resp then
				error('timed out: ' .. method)
			end
			return table.unpack(resp)
		end
	end

	return hijack, socket
end

return Proxy

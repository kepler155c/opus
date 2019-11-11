local Event  = require('opus.event')
local Socket = require('opus.socket')
local Util   = require('opus.util')

local function getProxy(path)
	local x = Util.split(path, '(.-)/')
	local proxy = _G
	for _, v in pairs(x) do
		proxy = proxy[v]
		if not proxy then
			break
		end
	end
	return proxy
end

local function proxyConnection(socket)
	local path = socket:read(2)
	if path then
		local api = getProxy(path)

		if not api then
			print('proxy: invalid API')
			socket:close()
			return
		end

		local methods = { }
		for k,v in pairs(api) do
			if type(v) == 'function' then
				table.insert(methods, k)
			end
		end
		socket:write(methods)

		while true do
			local data = socket:read()
			if not data then
				print('proxy: lost connection from ' .. socket.dhost)
				break
			end
			socket:write({ api[data[1]](table.unpack(data, 2)) })
		end
	end
end

Event.addRoutine(function()
	print('proxy: listening on port 188')
	while true do
		local socket = Socket.server(188)

		print('proxy: connection from ' .. socket.dhost)

		Event.addRoutine(function()
			local s, m = pcall(proxyConnection, socket)
			print('proxy: closing connection to ' .. socket.dhost)
			socket:close()
			if not s and m then
				print('Proxy error')
				_G.printError(m)
			end
		end)
	end
end)

local Event  = require('event')
local Socket = require('socket')
local Util   = require('util')

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

Event.addRoutine(function()
	while true do
		print('proxy: listening on port 188')
		local socket = Socket.server(188)

		print('proxy: connection from ' .. socket.dhost)

		Event.addRoutine(function()
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

				local s, m = pcall(function()
					while true do
						local data = socket:read()
						if not data then
							print('proxy: lost connection from ' .. socket.dhost)
							break
						end
						socket:write({ api[data[1]](table.unpack(data, 2)) })
					end
				end)
				if not s and m then
					_G.printError(m)
				end
			end
			socket:close()
		end)
	end
end)

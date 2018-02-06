--[[
	Allow sharing of local peripherals.
]]--

local Event      = require('event')
local Peripheral = require('peripheral')
local Socket     = require('socket')

Event.addRoutine(function()
	print('peripheral: listening on port 189')
	while true do
		local socket = Socket.server(189)

		print('peripheral: connection from ' .. socket.dhost)

		Event.addRoutine(function()
			local uri = socket:read(2)
			if uri then
				local peripheral = Peripheral.lookup(uri)

-- only 1 proxy of this device can happen at one time
-- need to prevent multiple shares
				if not peripheral then
					print('peripheral: invalid peripheral ' .. uri)
					socket:write('Invalid peripheral: ' .. uri)
				else
					print('peripheral: proxing ' .. uri)
					local proxy = {
						methods = { }
					}

					if peripheral.blit then
						--peripheral = Util.shallowCopy(peripheral)
						peripheral.fastBlit = function(data)
							for _,v in ipairs(data) do
								peripheral[v.fn](unpack(v.args))
							end
						end
					end

					for k,v in pairs(peripheral) do
						if type(v) == 'function' then
							table.insert(proxy.methods, k)
						else
							proxy[k] = v
						end
					end

					socket:write(proxy)

					if proxy.type == 'monitor' then
						peripheral.eventChannel = function(...)
							socket:write({
								fn = 'event',
								data = { ... }
							})
						end
					end

					while true do
						local data = socket:read()
						if not data then
							print('peripheral: lost connection from ' .. socket.dhost)
							break
						end
						if not _G.device[peripheral.name] then
							print('periperal: detached')
							socket:close()
							break
						end
						if peripheral[data.fn] then
							-- need to trigger an error on the other end
							-- local s, m = pcall()
							socket:write({ peripheral[data.fn](table.unpack(data.args)) })
						else
							socket:write({ false, "Invalid function: " .. data.fn })
						end
					end

					peripheral.eventChannel = nil
					peripheral.fastBlit = nil
				end
			end
		end)
	end
end)

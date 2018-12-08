local Event  = require('event')
local Socket = require('socket')
local Util   = require('util')

local os = _G.os

local Peripheral = Util.shallowCopy(_G.peripheral)

function Peripheral.getList()
	if _G.device then
		return _G.device
	end

	local deviceList = { }
	for _,side in pairs(Peripheral.getNames()) do
		Peripheral.addDevice(deviceList, side)
	end

	return deviceList
end

function Peripheral.addDevice(deviceList, side)
	local name = side
	local ptype = Peripheral.getType(side)

	if not ptype then
		return
	end

	if ptype == 'modem' then
		if not Peripheral.call(name, 'isWireless') then
--			ptype = 'wireless_modem'
--		else
			ptype = 'wired_modem'
		end
	end

	local sides = {
		front = true,
		back = true,
		top = true,
		bottom = true,
		left = true,
		right = true
	}

	if sides[name] then
		local i = 1
		local uniqueName = ptype
		while deviceList[uniqueName] do
			uniqueName = ptype .. '_' .. i
			i = i + 1
		end
		name = uniqueName
	end

	-- this can randomly fail
	if not deviceList[name] then
		pcall(function()
			deviceList[name] = Peripheral.wrap(side)
		end)

		if deviceList[name] then
			Util.merge(deviceList[name], {
				name = name,
				type = ptype,
				side = side,
			})
		end
	end

	return deviceList[name]
end

function Peripheral.getBySide(side)
	return Util.find(Peripheral.getList(), 'side', side)
end

function Peripheral.getByType(typeName)
	return Util.find(Peripheral.getList(), 'type', typeName)
end

function Peripheral.getByMethod(method)
	for _,p in pairs(Peripheral.getList()) do
		if p[method] then
			return p
		end
	end
end

-- match any of the passed arguments
function Peripheral.get(args)

	if type(args) == 'string' then
		args = { type = args }
	end

	if args.name then
		return _G.device[args.name]
	end

	if args.type then
		local p = Peripheral.getByType(args.type)
		if p then
			return p
		end
	end

	if args.method then
		local p = Peripheral.getByMethod(args.method)
		if p then
			return p
		end
	end

	if args.side then
		local p = Peripheral.getBySide(args.side)
		if p then
			return p
		end
	end
end

local function getProxy(pi)
	local socket, msg = Socket.connect(pi.host, 189)

	if not socket then
		error("Timed out attaching peripheral: " .. pi.uri .. '\n' .. msg)
	end

	-- write the uri of the periperal we are requesting...
	-- ie. type/monitor
	socket:write(pi.path)
	local proxy = socket:read(3)

	if not proxy then
		error("Timed out attaching peripheral: " .. pi.uri)
	end

	if type(proxy) == 'string' then
		error(proxy)
	end

	local methods = proxy.methods
	proxy.methods = nil

	for _,method in pairs(methods) do
		proxy[method] = function(...)
			socket:write({ fn = method, args = { ... } })
			local resp = socket:read()
			if not resp then
				error("Timed out communicating with peripheral: " .. pi.uri)
			end
			return table.unpack(resp)
		end
	end

	if proxy.blit then
		local methods = { 'clear', 'clearLine', 'setCursorPos', 'write', 'blit',
											'setTextColor', 'setTextColour', 'setBackgroundColor',
											'setBackgroundColour', 'scroll', 'setCursorBlink', }
		local queue = nil

		for _,method in pairs(methods) do
			proxy[method] = function(...)
				if not queue then
					queue = { }
					Event.onTimeout(0, function()
						if not socket:write({ fn = 'fastBlit', args = { queue } }) then
							error("Timed out communicating with peripheral: " .. pi.uri)
						end
						queue = nil
						socket:read()
					end)
				end
				if not socket.connected then
					error("Timed out communicating with peripheral: " .. pi.uri)
				end

				table.insert(queue, {
					fn = method,
					args = { ... },
				})
			end
		end
	end

	if proxy.type == 'monitor' then
		Event.addRoutine(function()
			while true do
				local data = socket:read()
				if not data then
					break
				end
				if data.fn and data.fn == 'event' then
					os.queueEvent(table.unpack(data.data))
				end
			end
		end)
	end

	return proxy
end

--[[
	Parse a uri into it's components

	Examples:
		monitor           = { name = 'monitor' }
		side/top          = { side = 'top' }
		method/list       = { method = 'list' }
		12://name/monitor = { host = 12, name = 'monitor' }
]]--
local function parse(uri)
	local pi = Util.split(uri:gsub('^%d*://', ''), '(.-)/')

	if #pi == 1 then
		pi = {
			'name',
			pi[1],
		}
	end

	return {
		host = uri:match('^(%d*)%:'),      -- 12
		uri  = uri,                        -- 12://name/monitor
		path = uri:gsub('^%d*://', ''),    -- name/monitor
		[ pi[1] ] = pi[2],                 -- name = 'monitor'
	}
end

function Peripheral.lookup(uri)
	local pi = parse(uri)

	if pi.host and _G.device.wireless_modem then
		return getProxy(pi)
	end

	return Peripheral.get(pi)
end

return Peripheral

local Util   = require('util')

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

return Peripheral

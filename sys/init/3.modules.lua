local Util       = require('opus.util')

local device     = _G.device
local kernel     = _G.kernel
local os         = _G.os

local containers = {
	manipulator = true,
	neuralInterface = true,
}

local cache = { }

-- manipulators will throw an error on listModules
-- if the user has logged off
local function getModules(dev, side)
	local list = { }
	local s, m = pcall(function()
		if dev and dev.listModules then
			for _, module in pairs(dev.listModules()) do
				list[module] = Util.shallowCopy(dev)
				list[module].name = module
				list[module].type = module
				list[module].side = side
			end
		end
	end)
	if not s and m then
		_G._syslog(m)
	end
	return list
end

-- if a device has been reattached, reuse the existing
-- table so any references to the table are retained
local function addDevice(dev, args, doQueue)
	local name = args.name

	if not cache[name] then
		cache[name] = { }
	end
	device[name] = cache[name]
	Util.merge(device[name], dev)
	Util.merge(device[name], args)

	if doQueue then
		os.queueEvent('device_attach', name)
	end
end

-- directly access the peripheral as the methods in getInventory, etc.
-- can become invalid without any way to tell
local function damnManipulator(container, method, args, doQueue)
	local dev = { }
	local methods = {
		'drop', 'getDocs', 'getItem', 'getItemMeta', 'getTransferLocations',
		'list', 'pullItems', 'pushItems', 'size', 'suck',
	}
	-- the user might not be logged in when the compputer is started
	-- and there's no way to know when they have logged in.
	-- these methods will error if the user is not logged in
	if container[method] then
		for _,k in pairs(methods) do
			dev[k] = function(...)
				return device[container.name][method]()[k](...)
			end
		end

		addDevice(dev, args, doQueue)
	end
end

local function addContainer(v, doQueue)
	-- add devices like plethora:scanner
	for name, dev in pairs(getModules(v, v.side)) do
		-- neural and attached modules have precedence over manipulator modules
		if not device[name] or v.type ~= 'manipulator' then
			addDevice(dev, { name = dev.name, type = dev.name, side = dev.side }, doQueue)
		end
	end

	if v.getName then
		local s, m = pcall(function()
			local name = v.getName()
			if name then
				damnManipulator(v, 'getInventory', {
					name = name .. ':inventory',
					type = 'inventory',
					side = v.side
				}, doQueue)
				damnManipulator(v, 'getEquipment', {
					name = name .. ':equipment',
					type = 'equipment',
					side = v.side
				}, doQueue)
				damnManipulator(v, 'getEnder', {
					name = name .. ':enderChest',
					type = 'enderChest',
					side = v.side
				}, doQueue)
			end
		end)
		if not s and m then
			_G._syslog(m)
		end
	end
end

for k,v in pairs(device) do
	if containers[v.type] then
		cache[k] = v
		addContainer(v)
	end
end

-- register modules as peripherals
kernel.hook('device_attach', function(_, eventData)
	local name = eventData[1]
	local dev = device[name]

	if dev and containers[dev.type] then
		-- so... basically, if you get a handle to device.neuralInterface
		-- (or manipulator) - that handle will still be valid after
		-- a module is removed
		if cache[name] then
			device[name] = cache[name]
			for k,v in pairs(device[name]) do
				if type(v) == 'function' then
					device[name][k] = nil
				end
			end
			Util.merge(device[name], dev)
		else
			cache[name] = dev
		end
		addContainer(dev, true)
	end
end)

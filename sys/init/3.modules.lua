local Util       = require('util')

local device     = _G.device
local kernel     = _G.kernel
local os         = _G.os
local peripheral = _G.peripheral

local containers = {
	manipulator = true,
	neuralInterface = true,
}

local function getModules(dev, side)
	local list = { }

	if dev then
		for _, module in pairs(dev.listModules()) do
			list[module] = Util.shallowCopy(dev)
			list[module].name = module
			list[module].type = module
			list[module].side = side
		end
	end
	return list
end

for _,v in pairs(device) do
	if containers[v.type] then
		local list = getModules(v, v.side)
		for k, dev in pairs(list) do
			-- neural and attached modules have precedence over manipulator modules
			if not device[k] or v.type ~= 'manipulator' then
				device[k] = dev
			end
		end
	end
end

-- register modules as peripherals
kernel.hook('device_attach', function(_, eventData)
	local dev = eventData[2]

	if dev and containers[dev.type] then
		local list = getModules(peripheral.wrap(dev.side), dev.side)
		for k,v in pairs(list) do
			if not device[k] or dev.type ~= 'manipulator' then
				device[k] = v
				os.queueEvent('device_attach', k, v)
			end
		end
	end
end)

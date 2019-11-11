local device     = _G.device
local kernel     = _G.kernel

local function register(v)
	if v and v.isWireless and v.isAccessPoint and v.getNamesRemote then
		v._children = { }
		for _, name in pairs(v.getNamesRemote()) do
			local dev = v.getMethodsRemote(name)
			if dev then
				dev.name = name
				dev.side = v.side
				dev.type = v.getTypeRemote(name)
				device[name] = dev
			end
		end
	end
end

for _,v in pairs(device) do
	register(v)
end

-- register oc devices as peripherals
kernel.hook('device_attach', function(_, eventData)
	register(device[eventData[1]])
end)

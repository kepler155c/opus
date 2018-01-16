local kernel = _G.kernel
local os     = _G.os

_G.network = { }

local function startNetwork()
	kernel.run({
		title = 'Net daemon',
		path = 'sys/apps/netdaemon.lua',
		hidden = true,
	})
end

kernel.hook('device_attach', function(_, eventData)
	if eventData[1] == 'wireless_modem' then
		startNetwork()
	end
end)

if _G.device.wireless_modem then
	startNetwork()
	os.sleep(0) -- give the network a cycle to start
end

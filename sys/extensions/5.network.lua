local kernel = _G.kernel

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
end


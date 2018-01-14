local kernel = _G.kernel

kernel.hook('device_attach', function(_, eventData)
	if eventData[1] == 'wireless_modem' then
		kernel.run({
			title = 'Net daemon',
			path = 'sys/extensions/netdaemon.lua',
			hidden = true,
		})
	end
end)

if _G.device.wireless_modem then

	_G.requireInjector(_ENV)
	local Config = require('config')

	local kernel = _G.kernel

	local config = { }
	Config.load('gps', config)

	if config.host and type(config.host) == 'table' then
		kernel.run({
			title  = 'GPS Daemon',
			hidden = true,
			path   = '/rom/programs/gps',
			args   = { 'host', config.host.x, config.host.y, config.host.z },
		})
	end
end

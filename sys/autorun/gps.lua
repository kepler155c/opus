local modem  = _G.device.wireless_modem
local turtle = _G.turtle

if turtle and modem then
	local s, m = turtle.run(function()

		_G.requireInjector(_ENV)

		local Config = require('config')
		local config = {
			destructive = false,
		}
		Config.load('gps', config)

		if config.home then

			local s = turtle.enableGPS(2)
			if not s then
				s = turtle.enableGPS(2)
			end
			if not s and config.destructive then
				turtle.setPolicy('turtleSafe')
				s = turtle.enableGPS(2)
			end

			if not s then
				error('Unable to get GPS position')
			end

			if config.destructive then
				turtle.setPolicy('turtleSafe')
			end

			if not turtle.pathfind(config.home) then
				error('Failed to return home')
			end
		end
	end)

	if not s and m then
		error(m)
	end
end

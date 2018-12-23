local Config = require('config')
local UI     = require('ui')

local fs     = _G.fs
local turtle = _G.turtle

if turtle then
	local Home = require('turtle.home')
	local values = { }
	Config.load('gps', values.home and { values.home } or { })

	local gpsTab = UI.Window {
		tabTitle = 'GPS',
		labelText = UI.Text {
			x = 3, y = 2,
			value = 'On restart, return to this location'
		},
		grid = UI.Grid {
			x = 3, ex = -3, y = 4,
			height = 2,
			values = values,
			inactive = true,
			columns = {
				{ heading = 'x', key = 'x' },
				{ heading = 'y', key = 'y' },
				{ heading = 'z', key = 'z' },
			},
		},
		button1 = UI.Button {
			x = 3, y = 7,
			text = 'Set home',
			event = 'gps_set',
		},
		button2 = UI.Button {
			ex = -3, y = 7, width = 7,
			text = 'Clear',
			event = 'gps_clear',
		},
	}
	function gpsTab:eventHandler(event)
		if event.type == 'gps_set' then
			self:emit({ type = 'info_message', message = 'Determining location' })
			self:sync()
			if Home.set() then
				Config.load('gps', values)
				self.grid:setValues(values.home and { values.home } or { })
				self.grid:draw()
				self:emit({ type = 'success_message', message = 'Location set' })
			else
				self:emit({ type = 'error_message', message = 'Unable to determine location' })
			end
			return true
		elseif event.type == 'gps_clear' then
			fs.delete('usr/config/gps')
			self.grid:setValues({ })
			self.grid:draw()
			return true
		end
	end

	return gpsTab
end

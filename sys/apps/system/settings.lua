local UI = require('ui')

local settings = _G.settings

if settings then

	local values = { }
	for _,v in pairs(settings.getNames()) do
		local value = settings.get(v)
		if not value then
			value = false
		end
		table.insert(values, {
			name = v,
			value = value,
		})
	end

	local settingsTab = UI.Window {
		tabTitle = 'Settings',
		description = 'Computercraft configurable settings',
		grid = UI.Grid {
			y = 1,
			values = values,
			autospace = true,
			sortColumn = 'name',
			columns = {
				{ heading = 'Setting',   key = 'name' },
				{ heading = 'Value', key = 'value'  },
			},
		},
	}

	function settingsTab:eventHandler(event)
		if event.type == 'grid_select' then
			if not event.selected.value or type(event.selected.value) == 'boolean' then
				event.selected.value = not event.selected.value
			end
			settings.set(event.selected.name, event.selected.value)
			settings.save('.settings')
			self.grid:draw()
			return true
		end
	end

	return settingsTab
end

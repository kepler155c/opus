local Config = require('opus.config')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local colors = _G.colors

local allColors = { }
for k,v in pairs(colors) do
	if type(v) == 'number' then
		table.insert(allColors, { name = k, value = v })
	end
end

local allSettings = { }
for k,v in pairs(UI.theme.colors) do
	allSettings[k] = { name = k, value = v }
end

return UI.Tab {
	title = 'Theme',
	description = 'Theme colors',
	grid1 = UI.ScrollingGrid {
		y = 2, ey = -10, x = 2, ex = -17,
		disableHeader = true,
		columns = { { key = 'name' } },
		values = allSettings,
		sortColumn = 'name',
	},
	grid2 = UI.ScrollingGrid {
		y = 2, ey = -10, x = -14, ex = -2,
		disableHeader = true,
		columns = { { key = 'name' } },
		values = allColors,
		sortColumn = 'name',
		getRowTextColor = function(self, row)
			local selected = self.parent.grid1:getSelected()
			if selected.value == row.value then
				return colors.yellow
			end
			return UI.Grid.getRowTextColor(self, row)
		end
	},
	button = UI.Button {
		x = -9, y = -2,
		text = 'Update',
		event = 'update',
	},
	display = UI.Window {
		x = 2, ex = -2, y = -8, height = 5,
		textColor = colors.black,
		backgroundColor = colors.black,
		draw = function(self)
			self:clear()

			self:write(1, 1, Util.widthify(' Local  Global  Device', self.width),
				allSettings.secondary.value)

			self:write(2, 2, 'enter command ',
				colors.black, colors.gray)

			self:write(1, 3, ' Formatted ',
				allSettings.primary.value)

			self:write(12, 3, Util.widthify(' Output ', self.width - 11),
				allSettings.tertiary.value)

			self:write(1, 4, Util.widthify(' Key', self.width),
				allSettings.primary.value)
		end,
	},
	eventHandler = function(self, event)
		if event.type == 'grid_focus_row' and event.element == self.grid1 then
			self.grid2:draw()

		elseif event.type == 'grid_select' and event.element == self.grid2 then
			self.grid1:getSelected().value = event.selected.value
			self.display:draw()
			self.grid2:draw()

		elseif event.type == 'update' then
			local config = Config.load('ui.theme', { colors = { } })
			for k,v in pairs(allSettings) do
				config.colors[k] = v.value
			end
			Config.update('ui.theme', config)
		end
		return UI.Tab.eventHandler(self, event)
	end
}

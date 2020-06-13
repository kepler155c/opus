local Config = require('opus.config')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local colors = _G.colors
local os     = _G.os

local config = Config.load('shellprompt')

local allColors = { }
for k,v in pairs(colors) do
	if type(v) == 'number' then
		table.insert(allColors, { name = k, value = v })
	end
end

local defaults = {
	textColor = colors.white,
	commandTextColor = colors.yellow,
	directoryTextColor  = colors.orange,
	promptTextColor = colors.blue,
	directoryColor = colors.green,
	fileColor = colors.white,
	backgroundColor = colors.black,
}
local _colors = config.color or Util.shallowCopy(defaults)

local allSettings = { }
for k in pairs(defaults) do
	table.insert(allSettings, { name = k })
end

-- temp
if not _colors.backgroundColor then
	_colors.backgroundColor = colors.black
	_colors.fileColor = colors.white
end

return UI.Tab {
	title = 'Shell',
	description = 'Shell options',
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
			if _colors[selected.name] == row.value then
				return colors.yellow
			end
			return UI.Grid.getRowTextColor(self, row)
		end
	},
	directory = UI.Checkbox {
		x = 2, y = -2,
		labelBackgroundColor = colors.black,
		label = 'Directory',
		value = config.displayDirectory
	},
	reset = UI.Button {
		x = -18, y = -2,
		text = 'Reset',
		event = 'reset',
	},
	button = UI.Button {
		x = -9, y = -2,
		text = 'Update',
		event = 'update',
	},
	display = UI.Window {
		x = 2, ex = -2, y = -8, height = 5,
		draw = function(self)
			self:clear(_colors.backgroundColor)
			local offset = 0
			if config.displayDirectory then
				self:write(1, 1,
					'==' .. os.getComputerLabel() .. ':/dir/etc',
					_colors.backgroundColor, _colors.directoryTextColor)
				offset = 1
			end

			self:write(1, 1 + offset, '$ ',
				_colors.backgroundColor, _colors.promptTextColor)

			self:write(3, 1 + offset, 'ls /',
				_colors.backgroundColor, _colors.commandTextColor)

			self:write(1, 2 + offset, 'sys    usr',
				_colors.backgroundColor, _colors.directoryColor)

			self:write(1, 3 + offset, 'startup',
				_colors.backgroundColor, _colors.fileColor)
		end,
	},
	eventHandler = function(self, event)
		if event.type =='checkbox_change' then
			config.displayDirectory = not not event.checked
			self.display:draw()

		elseif event.type == 'grid_focus_row' and event.element == self.grid1 then
			self.grid2:draw()

		elseif event.type == 'grid_select' and event.element == self.grid2 then
			_colors[self.grid1:getSelected().name] = event.selected.value
			self.display:draw()
			self.grid2:draw()

		elseif event.type == 'reset' then
			config.color = defaults
			config.displayDirectory = true
			self.directory.value = true
			_colors = Util.shallowCopy(defaults)

			Config.update('shellprompt', config)
			self:draw()

		elseif event.type == 'update' then
			config.color = _colors
			Config.update('shellprompt', config)

		end
		return UI.Tab.eventHandler(self, event)
	end
}

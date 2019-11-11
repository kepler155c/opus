local Array  = require('opus.array')
local Config = require('opus.config')
local UI     = require('opus.ui')

local colors     = _G.colors

local tab = UI.Tab {
	tabTitle = 'Preferred',
	description = 'Select preferred applications',
	apps = UI.ScrollingGrid {
		x = 2, y = 2,
		ex = 12, ey = -3,
		columns = {
			{ key = 'name' },
		},
		sortColumn = 'name',
		disableHeader = true,
	},
	choices = UI.Grid {
		x = 14, y = 2,
		ex = -2, ey = -3,
		disableHeader = true,
		columns = {
			{ key = 'file' },
		}
	},
	statusBar = UI.StatusBar {
		values = 'Double-click to set as preferred'
	},
}

function tab.choices:getRowTextColor(row)
	if row == self.values[1] then
		return colors.yellow
	end
	return UI.Grid.getRowTextColor(self, row)
end

function tab:updateChoices()
	local app = self.apps:getSelected().name
	local choices = { }
	for _, v in pairs(self.config[app]) do
		table.insert(choices, { file = v })
	end
	self.choices:setValues(choices)
	self.choices:draw()
end

function tab:enable()
	self.config = Config.load('alternate')

	local apps = { }
	for k, _ in pairs(self.config) do
		table.insert(apps, { name = k })
	end
	self.apps:setValues(apps)

	self:updateChoices()

	UI.Tab.enable(self)
end

function tab:eventHandler(event)
	if event.type == 'grid_focus_row' and event.element == self.apps then
		self:updateChoices()

	elseif event.type == 'grid_select' and event.element == self.choices then
		local app = self.apps:getSelected().name
		Array.removeByValue(self.config[app], event.selected.file)
		table.insert(self.config[app], 1, event.selected.file)
		self:updateChoices()
		Config.update('alternate', self.config)

	else
		return UI.Tab.eventHandler(self, event)
	end
	return true
end

return tab

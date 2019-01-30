local Config = require('config')
local UI     = require('ui')
local Util   = require('util')

local pathTab = UI.Tab {
	tabTitle = 'Path',
	description = 'Set the shell path',
	tabClose = true,
	entry = UI.TextEntry {
		x = 2, y = 2, ex = -2,
		limit = 256,
		value = Config.load('shell').path,
		shadowText = 'enter system path',
		accelerators = {
			enter = 'update_path',
		},
	},
	grid = UI.Grid {
		y = 4,
		disableHeader = true,
		columns = { { key = 'value' } },
		autospace = true,
	},
}

function pathTab.grid:draw()
	self.values = { }
	local env = Config.load('shell')
	for _,v in ipairs(Util.split(env.path, '(.-):')) do
		table.insert(self.values, { value = v })
	end
	self:update()
	UI.Grid.draw(self)
end

function pathTab:eventHandler(event)
	if event.type == 'update_path' then
		local env = Config.load('shell')
		env.path = self.entry.value
		Config.update('shell', env)
		self.grid:setIndex(self.grid:getIndex())
		self.grid:draw()
		self:emit({ type = 'success_message', message = 'reboot to take effect' })
		return true
	end
end

return pathTab

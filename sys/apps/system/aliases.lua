local Config = require('config')
local UI     = require('ui')

local aliasTab = UI.Window {
	tabTitle = 'Aliases',
	description = 'Shell aliases',
	alias = UI.TextEntry {
		x = 2, y = 2, ex = -2,
		limit = 32,
		shadowText = 'Alias',
	},
	path = UI.TextEntry {
		y = 3, x = 2, ex = -2,
		limit = 256,
		shadowText = 'Program path',
		accelerators = {
			enter = 'new_alias',
		},
	},
	grid = UI.Grid {
		y = 5,
		sortColumn = 'alias',
		columns = {
			{ heading = 'Alias',   key = 'alias' },
			{ heading = 'Program', key = 'path'  },
		},
		accelerators = {
			delete = 'delete_alias',
		},
	},
}

function aliasTab.grid:draw()
	self.values = { }
	local env = Config.load('shell')
	for k,v in pairs(env.aliases) do
		table.insert(self.values, { alias = k, path = v })
	end
	self:update()
	UI.Grid.draw(self)
end

function aliasTab:eventHandler(event)
	if event.type == 'delete_alias' then
		local env = Config.load('shell')
		env.aliases[self.grid:getSelected().alias] = nil
		self.grid:setIndex(self.grid:getIndex())
		self.grid:draw()
		Config.update('shell', env)
		self:emit({ type = 'success_message', message = 'reboot to take effect' })
		return true

	elseif event.type == 'new_alias' then
		local env = Config.load('shell')
		env.aliases[self.alias.value] = self.path.value
		self.alias:reset()
		self.path:reset()
		self:draw()
		self:setFocus(self.alias)
		Config.update('shell', env)
		self:emit({ type = 'success_message', message = 'reboot to take effect' })
		return true
	end
end

return aliasTab

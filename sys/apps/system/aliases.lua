local Config = require('opus.config')
local UI     = require('opus.ui')

local kernel = _G.kernel

local aliasTab = UI.Tab {
	title = 'Aliases',
	description = 'Shell aliases',
	alias = UI.TextEntry {
		x = 2, y = 2, ex = -2,
		limit = 32,
		shadowText = 'Alias',
	},
	path = UI.TextEntry {
		y = 3, x = 2, ex = -2,
		shadowText = 'Program path',
		accelerators = {
			enter = 'new_alias',
		},
	},
	grid = UI.Grid {
		x = 2, y = 5, ex = -2, ey = -2,
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
	for k in pairs(kernel.getShell().aliases()) do
		kernel.getShell().clearAlias(k)
	end
	for k,v in pairs(env.aliases) do
		table.insert(self.values, { alias = k, path = v })
		kernel.getShell().setAlias(k, v)
	end
	self:update()
	UI.Grid.draw(self)
end

function aliasTab:eventHandler(event)
	if event.type == 'delete_alias' then
		local env = Config.load('shell', { aliases = { } })
		env.aliases[self.grid:getSelected().alias] = nil
		Config.update('shell', env)
		self.grid:setIndex(self.grid:getIndex())
		self.grid:draw()
		self:emit({ type = 'success_message', message = 'Aliases updated' })
		return true

	elseif event.type == 'new_alias' then
		local env = Config.load('shell', { aliases = { } })
		env.aliases[self.alias.value] = self.path.value
		Config.update('shell', env)
		self.alias:reset()
		self.path:reset()
		self:draw()
		self:setFocus(self.alias)
		self:emit({ type = 'success_message', message = 'Aliases updated' })
		return true
	end
end

return aliasTab

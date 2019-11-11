local UI     = require('opus.ui')
local Util   = require('opus.util')

local fs     = _G.fs
local shell  = _ENV.shell

UI:configure('System', ...)

local systemPage = UI.Page {
	tabs = UI.Tabs {
		settings = UI.Tab {
			tabTitle = 'Category',
			grid = UI.ScrollingGrid {
				y = 2,
				columns = {
					{ heading = 'Name',        key = 'name'        },
					{ heading = 'Description', key = 'description' },
				},
				sortColumn = 'name',
				autospace = true,
			},
		},
	},
	notification = UI.Notification(),
	accelerators = {
		[ 'control-q' ] = 'quit',
	},
}

function systemPage.tabs.settings:eventHandler(event)
	if event.type == 'grid_select' then
		local tab = event.selected.tab
		if not systemPage.tabs[tab.tabTitle] then
			systemPage.tabs:add({ [ tab.tabTitle ] = tab })
			tab:disable()
		end
		systemPage.tabs:selectTab(tab)
		self.parent:draw()
		return true
	end
end

function systemPage:eventHandler(event)
	if event.type == 'quit' then
		UI:exitPullEvents()

	elseif event.type == 'success_message' then
		self.notification:success(event.message)

	elseif event.type == 'info_message' then
		self.notification:info(event.message)

	elseif event.type == 'error_message' then
		self.notification:error(event.message)

	elseif event.type == 'tab_activate' then
		event.activated:focusFirst()

	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

local function loadDirectory(dir)
	local plugins = { }
	for _, file in pairs(fs.list(dir)) do
		local s, m = Util.run(_ENV, fs.combine(dir, file))
		if not s and m then
			_G.printError('Error loading: ' .. file)
			error(m or 'Unknown error')
		elseif s and m then
			table.insert(plugins, { tab = m, name = m.tabTitle, description = m.description })
		end
	end
	return plugins
end

local programDir = fs.getDir(shell.getRunningProgram())
local plugins = loadDirectory(fs.combine(programDir, 'system'), { })

systemPage.tabs.settings.grid:setValues(plugins)

UI:setPage(systemPage)
UI:pullEvents()

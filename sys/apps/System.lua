local UI     = require('opus.ui')
local Util   = require('opus.util')

local fs     = _G.fs
local shell  = _ENV.shell

UI:configure('System', ...)

local function loadDirectory(dir)
	local plugins = { }
	for _, file in pairs(fs.list(dir)) do
		local s, m = Util.run(_ENV, fs.combine(dir, file))
		if not s and m then
			_G.printError('Error loading: ' .. file)
			error(m or 'Unknown error')
		elseif s and m then
			table.insert(plugins, { tab = m, name = m.title, description = m.description })
		end
	end
	return plugins
end

local programDir = fs.getDir(_ENV.arg[0])
local plugins = loadDirectory(fs.combine(programDir, 'system'), { })

local page = UI.Page {
	tabs = UI.Tabs {
		settings = UI.Tab {
			title = 'Category',
			grid = UI.ScrollingGrid {
				x = 2, y = 2, ex = -2, ey = -2,
				columns = {
					{ heading = 'Name',        key = 'name'        },
					{ heading = 'Description', key = 'description' },
				},
				sortColumn = 'name',
				autospace = true,
				values = plugins,
			},
			accelerators = {
				grid_select = 'category_select',
			}
		},
	},
	notification = UI.Notification(),
	accelerators = {
		[ 'control-q' ] = 'quit',
	},
	eventHandler = function(self, event)
		if event.type == 'quit' then
			UI:quit()

		elseif event.type == 'category_select' then
			local tab = event.selected.tab

			if not self.tabs[tab.title] then
				self.tabs:add({ [ tab.title ] = tab })
			end
			self.tabs:selectTab(tab)
			return true

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
	end,
}

UI:setPage(page)
UI:start()

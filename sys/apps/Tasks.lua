_G.requireInjector(_ENV)

local Event = require('event')
local UI    = require('ui')
local Util  = require('util')

local kernel     = _G.kernel
local multishell = _ENV.multishell

UI:configure('Tasks', ...)

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Activate',  event = 'activate'  },
			{ text = 'Terminate', event = 'terminate' },
		},
	},
	grid = UI.ScrollingGrid {
		y = 2,
		columns = {
			{ heading = 'ID',     key = 'uid',      width = 3 },
			{ heading = 'Title',  key = 'title'     },
			{ heading = 'Status', key = 'status'    },
			{ heading = 'Time',   key = 'timestamp' },
		},
		values = kernel.routines,
		sortColumn = 'uid',
		autospace = true,
	},
	accelerators = {
		q = 'quit',
		space = 'activate',
		t = 'terminate',
	},
}

function page:eventHandler(event)
	local t = self.grid:getSelected()
	if t then
		if event.type == 'activate' or event.type == 'grid_select' then
			multishell.setFocus(t.uid)
		elseif event.type == 'terminate' then
			multishell.terminate(t.uid)
		end
	end
	if event.type == 'quit' then
		Event.exitPullEvents()
	end
	UI.Page.eventHandler(self, event)
end

function page.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	local elapsed = os.clock()-row.timestamp
	if elapsed < 60 then
		row.timestamp = string.format("%ds", math.floor(elapsed))
	else
		row.timestamp = string.format("%sm", math.floor(elapsed/6)/10)
	end
	row.status = row.isDead and 'error' or coroutine.status(row.co)
	return row
end

Event.onInterval(1, function()
	page.grid:update()
	page.grid:draw()
	page:sync()
end)

UI:setPage(page)
UI:pullEvents()

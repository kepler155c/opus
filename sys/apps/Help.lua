_G.requireInjector(_ENV)

local UI    = require('ui')
local Util  = require('util')

local colors     = _G.colors
local help       = _G.help

UI:configure('Help', ...)

local topics = { }
for _,topic in pairs(help.topics()) do
	if help.lookup(topic) then
		table.insert(topics, { name = topic })
	end
end

local page = UI.Page {
	labelText = UI.Text {
		x = 3, y = 2,
		value = 'Search',
	},
	filter = UI.TextEntry {
		x = 10, y = 2, ex = -3,
		limit = 32,
	},
	grid = UI.ScrollingGrid {
		y = 4,
		values = topics,
		columns = {
			{ heading = 'Topic', key = 'name' },
		},
		sortColumn = 'name',
	},
	accelerators = {
		q     = 'quit',
		enter = 'grid_select',
	},
}

local topicPage = UI.Page {
	backgroundColor = colors.black,
	titleBar = UI.TitleBar {
		title = 'text',
		previousPage = true,
	},
	helpText = UI.TextArea {
		backgroundColor = colors.black,
		x = 2, ex = -1, y = 3, ey = -2,
	},
	accelerators = {
		q = 'back',
		backspace = 'back',
	},
}

function topicPage:eventHandler(event)
	if event.type == 'back' then
		UI:setPreviousPage()
	end
	return UI.Page.eventHandler(self, event)
end

function page:eventHandler(event)
	if event.type == 'quit' then
		UI:exitPullEvents()

	elseif event.type == 'grid_select' then
		if self.grid:getSelected() then
			local name = self.grid:getSelected().name
			local f = help.lookup(name)

			topicPage.titleBar.title = name
			topicPage.helpText:setText(Util.readFile(f))

			UI:setPage(topicPage)
		end

	elseif event.type == 'text_change' then
		if #event.text == 0 then
			self.grid.values = topics
		else
			self.grid.values = { }
			for _,f in pairs(topics) do
				if string.find(f.name, event.text) then
					table.insert(self.grid.values, f)
				end
			end
		end
		self.grid:update()
		self.grid:setIndex(1)
		self.grid:draw()
	else
		return UI.Page.eventHandler(self, event)
	end
end

UI:setPage(page)
UI:pullEvents()

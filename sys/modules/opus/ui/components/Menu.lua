local class = require('opus.class')
local UI    = require('opus.ui')

UI.Menu = class(UI.Grid)
UI.Menu.defaults = {
	UIElement = 'Menu',
	disableHeader = true,
	columns = { { heading = 'Prompt', key = 'prompt', width = 20 } },
	menuItems = { },
}
function UI.Menu:postInit()
	self.values = self.menuItems
	self.pageSize = #self.menuItems
end

function UI.Menu:layout()
	self.itemWidth = 1
	for _,v in pairs(self.values) do
		if #v.prompt > self.itemWidth then
			self.itemWidth = #v.prompt
		end
	end
	self.columns[1].width = self.itemWidth

	if self.centered then
		self:center()
	else
		self.width = self.itemWidth + 2
	end
	UI.Grid.layout(self)
end

function UI.Menu:center()
	self.x = (self.width - self.itemWidth + 2) / 2
	self.width = self.itemWidth + 2
end

function UI.Menu:eventHandler(event)
	if event.type == 'key' then
		if event.key == 'enter' then
			local selected = self.menuItems[self.index]
			self:emit({
				type = selected.event or 'menu_select',
				selected = selected
			})
			return true
		end
	elseif event.type == 'mouse_click' then
		if event.y <= #self.menuItems then
			UI.Grid.setIndex(self, event.y)
			local selected = self.menuItems[self.index]
			self:emit({
				type = selected.event or 'menu_select',
				selected = selected
			})
			return true
		end
	end
	return UI.Grid.eventHandler(self, event)
end

function UI.Menu.example()
	return UI.Menu {
		x = 2, y = 2, height = 3,
		menuItems = {
			{ prompt = 'Start',    event = 'start' },
			{ prompt = 'Continue', event = 'continue' },
			{ prompt = 'Quit',     event = 'quit' }
		}
	}
end

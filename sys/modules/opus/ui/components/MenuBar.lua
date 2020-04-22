local class = require('opus.class')
local UI    = require('opus.ui')

UI.MenuBar = class(UI.Window)
UI.MenuBar.defaults = {
	UIElement = 'MenuBar',
	buttons = { },
	height = 1,
	backgroundColor = 'secondary',
	textColor = 'black',
	spacing = 2,
	lastx = 1,
	buttonClass = 'MenuItem',
}
function UI.MenuBar:postInit()
	self:addButtons(self.buttons)
end

function UI.MenuBar:addButtons(buttons)
	if not self.children then
		self.children = { }
	end

	for _,button in pairs(buttons) do
		if button.index then -- don't sort unless needed
			table.sort(buttons, function(a, b)
				return (a.index or 999) < (b.index or 999)
			end)
			break
		end
	end

	for _,button in pairs(buttons) do
		if button.UIElement then
			table.insert(self.children, button)
		else
			local buttonProperties = {
				x = self.lastx,
				width = #(button.text or 'button') + self.spacing,
				centered = false,
				backgroundColor = self.backgroundColor,
			}
			self.lastx = self.lastx + buttonProperties.width
			UI:mergeProperties(buttonProperties, button)

			button = UI[self.buttonClass](buttonProperties)
			if button.name then
				self[button.name] = button
			else
				table.insert(self.children, button)
			end
		end
	end
	if self.parent then
		self:initChildren()
	end
end

function UI.MenuBar:getActive(menuItem)
	return not menuItem.inactive
end

function UI.MenuBar:eventHandler(event)
	if event.type == 'button_press' and event.button.dropdown then
		local function getPosition(element)
			local x, y = 1, 1
			repeat
				x = element.x + x - 1
				y = element.y + y - 1
				element = element.parent
			until not element
			return x, y
		end

		local x, y = getPosition(event.button)

		local menu = UI.DropMenu {
			buttons = event.button.dropdown,
			x = x,
			y = y + 1,
			lastFocus = event.button.uid,
			menuUid = self.uid,
		}
		self.parent:add({ dropmenu = menu })

		return true
	end
end

function UI.MenuBar.example()
	return UI.MenuBar {
		buttons = {
			{ text = 'Choice1', event = 'event1' },
			{ text = 'Choice2', event = 'event2', inactive = true },
			{ text = 'Choice3', event = 'event3' },
		}
	}
end

local class = require('opus.class')
local UI    = require('opus.ui')

local colors = _G.colors

local function getPosition(element)
	local x, y = 1, 1
	repeat
		x = element.x + x - 1
		y = element.y + y - 1
		element = element.parent
	until not element
	return x, y
end

UI.MenuBar = class(UI.Window)
UI.MenuBar.defaults = {
	UIElement = 'MenuBar',
	buttons = { },
	height = 1,
	backgroundColor = colors.lightGray,
	textColor = colors.black,
	spacing = 2,
	lastx = 1,
	showBackButton = false,
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
		if button.UIElement then
			table.insert(self.children, button)
		else
			local buttonProperties = {
				x = self.lastx,
				width = #(button.text or 'button') + self.spacing,
				centered = false,
			}
			self.lastx = self.lastx + buttonProperties.width
			UI:mergeProperties(buttonProperties, button)

			button = UI[self.buttonClass](buttonProperties)
			if button.name then
				self[button.name] = button
			else
				table.insert(self.children, button)
			end

			if button.dropdown then
				button.dropmenu = UI.DropMenu { buttons = button.dropdown }
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
	if event.type == 'button_press' and event.button.dropmenu then
		if event.button.dropmenu.enabled then
			event.button.dropmenu:hide()
			self:refocus()
			return true
		else
			local x, y = getPosition(event.button)
			if x + event.button.dropmenu.width > self.width then
				x = self.width - event.button.dropmenu.width + 1
			end
			for _,c in pairs(event.button.dropmenu.children) do
				if not c.spacer then
					c.inactive = not self:getActive(c)
				end
			end
			event.button.dropmenu:show(x, y + 1)
		end
		return true
	end
end

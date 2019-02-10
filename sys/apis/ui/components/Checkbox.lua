local class = require('class')
local UI    = require('ui')

local colors = _G.colors

UI.Checkbox = class(UI.Window)
UI.Checkbox.defaults = {
	UIElement = 'Checkbox',
	nochoice = 'Select',
	checkedIndicator = 'X',
	leftMarker = '[',
	rightMarker = ']',
	value = false,
	textColor = colors.white,
	backgroundColor = colors.black,
	backgroundFocusColor = colors.lightGray,
	height = 1,
	accelerators = {
		space = 'checkbox_toggle',
		mouse_click = 'checkbox_toggle',
	}
}
function UI.Checkbox:setParent()
	if not self.width and not self.ex then
		self.width = (self.label and #self.label or 0) + 3
	else
		self.width = 3
	end
	UI.Window.setParent(self)
end

function UI.Checkbox:draw()
	local bg = self.backgroundColor
	if self.focused then
		bg = self.backgroundFocusColor
	end
	if type(self.value) == 'string' then
		self.value = nil  -- TODO: fix form
	end
	local text = string.format('[%s]', not self.value and ' ' or self.checkedIndicator)
	local x = 1
	if self.label then
		self:write(1, 1, self.label)
		x = #self.label + 2
	end
	self:write(x,     1, text, bg)
	self:write(x,     1, self.leftMarker, self.backgroundColor, self.textColor)
	self:write(x + 1, 1, not self.value and ' ' or self.checkedIndicator, bg)
	self:write(x + 2, 1, self.rightMarker, self.backgroundColor, self.textColor)
end

function UI.Checkbox:focus()
	self:draw()
end

function UI.Checkbox:reset()
	self.value = false
end

function UI.Checkbox:eventHandler(event)
	if event.type == 'checkbox_toggle' then
		self.value = not self.value
		self:emit({ type = 'checkbox_change', checked = self.value, element = self })
		self:draw()
		return true
	end
end

local class = require('class')
local UI    = require('ui')
local Util  = require('util')

local colors = _G.colors

UI.DropMenu = class(UI.MenuBar)
UI.DropMenu.defaults = {
	UIElement = 'DropMenu',
	backgroundColor = colors.white,
	buttonClass = 'DropMenuItem',
}
function UI.DropMenu:setParent()
	UI.MenuBar.setParent(self)

	local maxWidth = 1
	for y,child in ipairs(self.children) do
		child.x = 1
		child.y = y
		if #(child.text or '') > maxWidth then
			maxWidth = #child.text
		end
	end
	for _,child in ipairs(self.children) do
		child.width = maxWidth + 2
		if child.spacer then
			child.text = string.rep('-', child.width - 2)
		end
	end

	self.height = #self.children + 1
	self.width = maxWidth + 2
	self.ow = self.width

	self.canvas = self:addLayer()
end

function UI.DropMenu:enable()
end

function UI.DropMenu:show(x, y)
	self.x, self.y = x, y
	self.canvas:move(x, y)
	self.canvas:setVisible(true)

	UI.Window.enable(self)

	self:draw()
	self:capture(self)
	self:focusFirst()
end

function UI.DropMenu:hide()
	self:disable()
	self.canvas:setVisible(false)
	self:release(self)
end

function UI.DropMenu:eventHandler(event)
	if event.type == 'focus_lost' and self.enabled then
		if not Util.contains(self.children, event.focused) then
			self:hide()
		end
	elseif event.type == 'mouse_out' and self.enabled then
		self:hide()
		self:refocus()
	else
		return UI.MenuBar.eventHandler(self, event)
	end
	return true
end

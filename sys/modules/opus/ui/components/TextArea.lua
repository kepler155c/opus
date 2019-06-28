local class = require('opus.class')
local UI    = require('opus.ui')

--[[-- TextArea --]]--
UI.TextArea = class(UI.Viewport)
UI.TextArea.defaults = {
	UIElement = 'TextArea',
	marginRight = 2,
	value = '',
}
function UI.TextArea:postInit()
	self.scrollBar = UI.ScrollBar()
end

function UI.TextArea:setText(text)
	self:reset()
	self.value = text
	self:draw()
end

function UI.TextArea:focus()
	-- allow keyboard scrolling
end

function UI.TextArea:draw()
	self:clear()
--  self:setCursorPos(1, 1)
	self.cursorX, self.cursorY = 1, 1
	self:print(self.value)

	for _,child in pairs(self.children) do
		if child.enabled then
			child:draw()
		end
	end
end

local class = require('opus.class')
local UI    = require('opus.ui')

UI.Tab = class(UI.Window)
UI.Tab.defaults = {
	UIElement = 'Tab',
	tabTitle = 'tab',
	y = 2,
}

function UI.Tab:draw()
	if not self.noFill then
		self:fillArea(1, 1, self.width, self.height, string.rep('\127', self.width), colors.black, colors.gray)
	end
	self:drawChildren()
end

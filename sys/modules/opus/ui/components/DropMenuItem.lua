local class = require('opus.class')
local UI    = require('opus.ui')

local colors = _G.colors

--[[-- DropMenuItem --]]--
UI.DropMenuItem = class(UI.Button)
UI.DropMenuItem.defaults = {
	UIElement = 'DropMenuItem',
	textColor = colors.black,
	backgroundColor = colors.white,
	textFocusColor = colors.white,
	textInactiveColor = colors.lightGray,
	backgroundFocusColor = colors.lightGray,
}
function UI.DropMenuItem:eventHandler(event)
	if event.type == 'button_activate' then
		self.parent:hide()
	end
	return UI.Button.eventHandler(self, event)
end

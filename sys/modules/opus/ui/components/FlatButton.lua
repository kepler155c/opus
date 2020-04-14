local class = require('opus.class')
local UI    = require('opus.ui')

local colors = _G.colors

UI.FlatButton = class(UI.Button)
UI.FlatButton.defaults = {
	UIElement = 'FlatButton',
	textColor = colors.black,
	textFocusColor = colors.white,
	noPadding = true,
}
function UI.FlatButton:setParent()
	self.backgroundColor = self.parent:getProperty('backgroundColor')
	self.backgroundFocusColor = self.backgroundColor

	UI.Button.setParent(self)
end

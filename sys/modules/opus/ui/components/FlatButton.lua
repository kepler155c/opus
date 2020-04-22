local class = require('opus.class')
local UI    = require('opus.ui')

UI.FlatButton = class(UI.Button)
UI.FlatButton.defaults = {
	UIElement = 'FlatButton',
	textColor = 'black',
	textFocusColor = 'white',
	noPadding = true,
}
function UI.FlatButton:setParent()
	self.backgroundColor = self.parent:getProperty('backgroundColor')
	self.backgroundFocusColor = self.backgroundColor

	UI.Button.setParent(self)
end

local class = require('opus.class')
local UI    = require('opus.ui')

UI.DropMenuItem = class(UI.Button)
UI.DropMenuItem.defaults = {
	UIElement = 'DropMenuItem',
	textColor = 'black',
	backgroundColor = 'white',
	textFocusColor = 'white',
	textInactiveColor = 'lightGray',
	backgroundFocusColor = 'lightGray',
}
function UI.DropMenuItem:eventHandler(event)
	if event.type == 'button_activate' then
		self.parent:disable()
	end
	return UI.Button.eventHandler(self, event)
end

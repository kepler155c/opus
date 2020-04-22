local class = require('opus.class')
local UI    = require('opus.ui')

UI.MenuItem = class(UI.FlatButton)
UI.MenuItem.defaults = {
	UIElement = 'MenuItem',
	noPadding = false,
	textInactiveColor = 'gray',
}

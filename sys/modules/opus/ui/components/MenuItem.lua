local class = require('opus.class')
local UI    = require('opus.ui')

local colors = _G.colors

UI.MenuItem = class(UI.Button)
UI.MenuItem.defaults = {
	UIElement = 'MenuItem',
	textFocusColor = colors.white,
	backgroundFocusColor = colors.lightGray,
}

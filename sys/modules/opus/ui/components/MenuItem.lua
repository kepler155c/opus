local class = require('opus.class')
local UI    = require('opus.ui')

local colors = _G.colors

--[[-- MenuItem --]]--
UI.MenuItem = class(UI.Button)
UI.MenuItem.defaults = {
	UIElement = 'MenuItem',
	textColor = colors.black,
	backgroundColor = colors.lightGray,
	textFocusColor = colors.white,
	backgroundFocusColor = colors.lightGray,
}

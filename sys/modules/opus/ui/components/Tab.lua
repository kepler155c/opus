local class = require('opus.class')
local UI    = require('opus.ui')

local colors = _G.colors

UI.Tab = class(UI.ActiveLayer)
UI.Tab.defaults = {
	UIElement = 'Tab',
	tabTitle = 'tab',
	backgroundColor = colors.cyan,
	y = 2,
}

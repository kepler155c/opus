local class = require('opus.class')
local UI    = require('opus.ui')

UI.Tab = class(UI.ActiveLayer)
UI.Tab.defaults = {
	UIElement = 'Tab',
	tabTitle = 'tab',
	y = 2,
}

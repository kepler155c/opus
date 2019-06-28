local class = require('opus.class')
local UI    = require('opus.ui')

local colors = _G.colors

--[[-- TabBarMenuItem --]]--
UI.TabBarMenuItem = class(UI.Button)
UI.TabBarMenuItem.defaults = {
	UIElement = 'TabBarMenuItem',
	event = 'tab_select',
	textColor = colors.black,
	selectedBackgroundColor = colors.cyan,
	unselectedBackgroundColor = colors.lightGray,
	backgroundColor = colors.lightGray,
}
function UI.TabBarMenuItem:draw()
	if self.selected then
		self.backgroundColor = self.selectedBackgroundColor
		self.backgroundFocusColor = self.selectedBackgroundColor
	else
		self.backgroundColor = self.unselectedBackgroundColor
		self.backgroundFocusColor = self.unselectedBackgroundColor
	end
	UI.Button.draw(self)
end

local class = require('opus.class')
local UI    = require('opus.ui')

UI.TabBarMenuItem = class(UI.Button)
UI.TabBarMenuItem.defaults = {
	UIElement = 'TabBarMenuItem',
	event = 'tab_select',
}
function UI.TabBarMenuItem:draw()
	if self.selected then
		self.backgroundColor = self:getProperty('selectedBackgroundColor')
		self.backgroundFocusColor = self.backgroundColor
		self.textColor = self:getProperty('selectedTextColor')
	else
		self.backgroundColor = self:getProperty('unselectedBackgroundColor')
		self.backgroundFocusColor = self.backgroundColor
		self.textColor = self:getProperty('unselectedTextColor')
	end
	UI.Button.draw(self)
end

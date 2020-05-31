local class = require('opus.class')
local UI    = require('opus.ui')
local Util  = require('opus.util')

UI.TabBar = class(UI.MenuBar)
UI.TabBar.defaults = {
	UIElement = 'TabBar',
	buttonClass = 'TabBarMenuItem',
	backgroundColor = 'black',
}
function UI.TabBar:enable()
	UI.MenuBar.enable(self)
	if not Util.find(self.children, 'selected', true) then
		local menuItem = self:getFocusables()[1]
		if menuItem then
			menuItem.selected = true
		end
	end
end

function UI.TabBar:eventHandler(event)
	if event.type == 'tab_select' then
		local selected, si = Util.find(self.children, 'uid', event.button.uid)
		local previous, pi = Util.find(self.children, 'selected', true)

		if si ~= pi then
			selected.selected = true
			if previous then
				previous.selected = false
				self:emit({ type = 'tab_change', current = si, last = pi, tab = selected })
			end
		end
		self:draw(self)
	end
	return UI.MenuBar.eventHandler(self, event)
end


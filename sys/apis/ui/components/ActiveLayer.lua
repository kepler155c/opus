local class = require('class')
local UI    = require('ui')

UI.ActiveLayer = class(UI.Window)
UI.ActiveLayer.defaults = {
	UIElement = 'ActiveLayer',
}
function UI.ActiveLayer:setParent()
	self:layout(self)
	self.canvas = self:addLayer()

	UI.Window.setParent(self)
end

function UI.ActiveLayer:enable(...)
	self.canvas:raise()
	self.canvas:setVisible(true)
	UI.Window.enable(self, ...)
	if self.parent.transitionHint then
		self:addTransition(self.parent.transitionHint)
	end
	self:focusFirst()
end

function UI.ActiveLayer:disable()
	if self.canvas then
		self.canvas:setVisible(false)
	end
	UI.Window.disable(self)
end

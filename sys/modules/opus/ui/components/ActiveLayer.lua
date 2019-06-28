local class = require('opus.class')
local UI    = require('opus.ui')

UI.ActiveLayer = class(UI.Window)
UI.ActiveLayer.defaults = {
	UIElement = 'ActiveLayer',
}
function UI.ActiveLayer:layout()
	UI.Window.layout(self)
	if not self.canvas then
		self.canvas = self:addLayer()
	else
		self.canvas:resize(self.width, self.height)
	end
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

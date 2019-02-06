local class = require('class')
local UI    = require('ui')

--[[-- SlideOut --]]--
UI.SlideOut = class(UI.Window)
UI.SlideOut.defaults = {
	UIElement = 'SlideOut',
	pageType = 'modal',
}
function UI.SlideOut:setParent()
	-- TODO: size should be set at this point
	self:layout()
	self.canvas = self:addLayer()

	UI.Window.setParent(self)
end

function UI.SlideOut:enable()
end

function UI.SlideOut:show(...)
	self:addTransition('expandUp')
	self.canvas:raise()
	self.canvas:setVisible(true)
	UI.Window.enable(self, ...)
	self:draw()
	self:capture(self)
	self:focusFirst()
end

function UI.SlideOut:disable()
	self.canvas:setVisible(false)
	UI.Window.disable(self)
end

function UI.SlideOut:hide()
	self:disable()
	self:release(self)
	self:refocus()
end

function UI.SlideOut:eventHandler(event)
	if event.type == 'slide_show' then
		self:show()
		return true

	elseif event.type == 'slide_hide' then
		self:hide()
		return true
	end
end

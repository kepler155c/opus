local class    = require('opus.class')
local Terminal = require('opus.terminal')
local UI       = require('opus.ui')

local colors = _G.colors

UI.Embedded = class(UI.Window)
UI.Embedded.defaults = {
	UIElement = 'Embedded',
	backgroundColor = colors.black,
	textColor = colors.white,
	maxScroll = 100,
	accelerators = {
		up = 'scroll_up',
		down = 'scroll_down',
	}
}
function UI.Embedded:setParent()
	UI.Window.setParent(self)

	self.win = Terminal.window(UI.term.device, self.x, self.y, self.width, self.height, false)
	self.win.setMaxScroll(self.maxScroll)

	local canvas = self:getCanvas()
	self.win.getCanvas().parent = canvas
	table.insert(canvas.layers, self.win.getCanvas())
	self.canvas = self.win.getCanvas()

	self.win.setCursorPos(1, 1)
	self.win.setBackgroundColor(self.backgroundColor)
	self.win.setTextColor(self.textColor)
	self.win.clear()
end

function UI.Embedded:layout()
	UI.Window.layout(self)
	if self.win then
		self.win.reposition(self.x, self.y, self.width, self.height)
	end
end

function UI.Embedded:draw()
	self.canvas:dirty()
end

function UI.Embedded:enable()
	self.canvas:setVisible(true)
	self.canvas:raise()
	if self.visible then
		-- the window will automatically update on changes
		-- the canvas does not need to be rendereed
		self.win.setVisible(true)
	end
	UI.Window.enable(self)
	self.canvas:dirty()
end

function UI.Embedded:disable()
	self.canvas:setVisible(false)
	self.win.setVisible(false)
	UI.Window.disable(self)
end

function UI.Embedded:eventHandler(event)
	if event.type == 'scroll_up' then
		self.win.scrollUp()
		return true
	elseif event.type == 'scroll_down' then
		self.win.scrollDown()
		return true
	end
end

function UI.Embedded:focus()
	-- allow scrolling
end

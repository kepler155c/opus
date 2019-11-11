local class = require('opus.class')
local UI    = require('opus.ui')

local colors = _G.colors

--[[-- Viewport --]]--
UI.Viewport = class(UI.Window)
UI.Viewport.defaults = {
	UIElement = 'Viewport',
	backgroundColor = colors.cyan,
	accelerators = {
		down            = 'scroll_down',
		up              = 'scroll_up',
		home            = 'scroll_top',
		[ 'end' ]       = 'scroll_bottom',
		pageUp          = 'scroll_pageUp',
		[ 'control-b' ] = 'scroll_pageUp',
		pageDown        = 'scroll_pageDown',
		[ 'control-f' ] = 'scroll_pageDown',
	},
}
function UI.Viewport:layout()
	UI.Window.layout(self)
	if not self.canvas then
		self.canvas = self:addLayer()
	else
		self.canvas:resize(self.width, self.height)
	end
end

function UI.Viewport:enable()
	UI.Window.enable(self)
	self.canvas:setVisible(true)
end

function UI.Viewport:disable()
	UI.Window.disable(self)
	self.canvas:setVisible(false)
end

function UI.Viewport:setScrollPosition(offset)
	local oldOffset = self.offy
	self.offy = math.max(offset, 0)
	self.offy = math.min(self.offy, math.max(#self.canvas.lines, self.height) - self.height)
	if self.offy ~= oldOffset then
		if self.scrollBar then
			self.scrollBar:draw()
		end
		self.canvas.offy = offset
		self.canvas:dirty()
	end
end

function UI.Viewport:write(x, y, text, bg, tc)
	if y > #self.canvas.lines then
		for i = #self.canvas.lines, y do
			self.canvas.lines[i + 1] = { }
			self.canvas:clearLine(i + 1, self.backgroundColor, self.textColor)
		end
	end
	return UI.Window.write(self, x, y, text, bg, tc)
end

function UI.Viewport:reset()
	self.offy = 0
	self.canvas.offy = 0
	for i = self.height + 1, #self.canvas.lines do
		self.canvas.lines[i] = nil
	end
end

function UI.Viewport:getViewArea()
	return {
		y           = (self.offy or 0) + 1,
		height      = self.height,
		totalHeight = #self.canvas.lines,
		offsetY     = self.offy or 0,
	}
end

function UI.Viewport:eventHandler(event)
	if event.type == 'scroll_down' then
		self:setScrollPosition(self.offy + 1)
	elseif event.type == 'scroll_up' then
		self:setScrollPosition(self.offy - 1)
	elseif event.type == 'scroll_top' then
		self:setScrollPosition(0)
	elseif event.type == 'scroll_bottom' then
		self:setScrollPosition(10000000)
	elseif event.type == 'scroll_pageUp' then
		self:setScrollPosition(self.offy - self.height)
	elseif event.type == 'scroll_pageDown' then
		self:setScrollPosition(self.offy + self.height)
	elseif event.type == 'scroll_to' then
		self:setScrollPosition(event.offset)
	else
		return false
	end
	return true
end

local class = require('opus.class')
local UI    = require('opus.ui')

UI.Viewport = class(UI.Window)
UI.Viewport.defaults = {
	UIElement = 'Viewport',
	accelerators = {
		down            = 'scroll_down',
		up              = 'scroll_up',
		home            = 'scroll_top',
		left            = 'scroll_left',
		right           = 'scroll_right',
		[ 'end' ]       = 'scroll_bottom',
		pageUp          = 'scroll_pageUp',
		[ 'control-b' ] = 'scroll_pageUp',
		pageDown        = 'scroll_pageDown',
		[ 'control-f' ] = 'scroll_pageDown',
	},
}
function UI.Viewport:postInit()
	if self.showScrollBar then
		self.scrollBar = UI.ScrollBar()
	end
end

function UI.Viewport:setScrollPosition(offy, offx) -- argh - reverse
	local oldOffy = self.offy
	self.offy = math.max(offy, 0)
	self.offy = math.min(self.offy, math.max(#self.lines, self.height) - self.height)
	if self.offy ~= oldOffy then
		if self.scrollBar then
			self.scrollBar:draw()
		end
		self.offy = offy
		self:dirty(true)
	end

	local oldOffx = self.offx
	self.offx = math.max(offx or 0, 0)
	self.offx = math.min(self.offx, math.max(#self.lines[1], self.width) - self.width)
	if self.offx ~= oldOffx then
		if self.scrollBar then
			--self.scrollBar:draw()
		end
		self.offx = offx or 0
		self:dirty(true)
	end
end

function UI.Viewport:blit(x, y, text, bg, fg)
	if y > #self.lines then
		self:resizeBuffer(self.width, y)
	end
	return UI.Window.blit(self, x, y, text, bg, fg)
end

function UI.Viewport:write(x, y, text, bg, fg)
	if y > #self.lines then
		self:resizeBuffer(self.width, y)
	end
	return UI.Window.write(self, x, y, text, bg, fg)
end

function UI.Viewport:setViewHeight(h)
	if h > #self.lines then
		self:resizeBuffer(self.width, h)
	end
end

function UI.Viewport:reset()
	self.offy = 0
	for i = self.height + 1, #self.lines do
		self.lines[i] = nil
	end
end

function UI.Viewport:getViewArea()
	return {
		y           = (self.offy or 0) + 1,
		height      = self.height,
		totalHeight = #self.lines,
		offsetY     = self.offy or 0,
	}
end

function UI.Viewport:eventHandler(event)
	if #self.lines <= self.height then
		return
	end
	if event.type == 'scroll_down' then
		self:setScrollPosition(self.offy + 1, self.offx)
	elseif event.type == 'scroll_up' then
		self:setScrollPosition(self.offy - 1, self.offx)
	elseif event.type == 'scroll_left' then
		self:setScrollPosition(self.offy, self.offx - 1)
	elseif event.type == 'scroll_right' then
		self:setScrollPosition(self.offy, self.offx + 1)
	elseif event.type == 'scroll_top' then
		self:setScrollPosition(0, 0)
	elseif event.type == 'scroll_bottom' then
		self:setScrollPosition(10000000, 0)
	elseif event.type == 'scroll_pageUp' then
		self:setScrollPosition(self.offy - self.height, self.offx)
	elseif event.type == 'scroll_pageDown' then
		self:setScrollPosition(self.offy + self.height, self.offx)
	elseif event.type == 'scroll_to' then
		self:setScrollPosition(event.offset, 0)
	else
		return false
	end
	return true
end

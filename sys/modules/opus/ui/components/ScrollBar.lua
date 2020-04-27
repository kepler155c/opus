local class = require('opus.class')
local UI    = require('opus.ui')
local Util  = require('opus.util')

local colors = _G.colors

UI.ScrollBar = class(UI.Window)
UI.ScrollBar.defaults = {
	UIElement = 'ScrollBar',
	lineChar = '\166',
	sliderChar = UI.extChars and '\127' or '#',
	upArrowChar = UI.extChars and '\30' or '^',
	downArrowChar = UI.extChars and '\31' or 'v',
	scrollbarColor = colors.lightGray,
	width = 1,
	x = -1,
	ey = -1,
}
function UI.ScrollBar:draw()
	local parent = self.target or self.parent --self:find(self.target)
	local view = parent:getViewArea()

	self:clear()

	-- ...
	self:write(1, 1, ' ', view.fill)

	if view.totalHeight > view.height then
		local maxScroll = view.totalHeight - view.height
		local percent = view.offsetY / maxScroll
		local sliderSize = math.max(1, Util.round(view.height / view.totalHeight * (view.height - 2)))
		local x = self.width

		local row = view.y
		if not view.static then  -- does the container scroll ?
			self:reposition(self.x, self.y, self.width, view.totalHeight)
		end

		for i = 1, view.height - 2 do
			self:write(x, row + i, self.lineChar, nil, self.scrollbarColor)
		end

		local y = Util.round((view.height - 2 - sliderSize) * percent)
		for i = 1, sliderSize do
			self:write(x, row + y + i, self.sliderChar, nil, self.scrollbarColor)
		end

		local color = self.scrollbarColor
		if view.offsetY > 0 then
			color = colors.white
		end
		self:write(x, row, self.upArrowChar, nil, color)

		color = self.scrollbarColor
		if view.offsetY + view.height < view.totalHeight then
			color = colors.white
		end
		self:write(x, row + view.height - 1, self.downArrowChar, nil, color)
	end
end

function UI.ScrollBar:eventHandler(event)
	if event.type == 'mouse_click' or event.type == 'mouse_doubleclick' then
		if event.x == 1 then
			local parent = self.target or self.parent --self:find(self.target)
			local view = parent:getViewArea()
			if view.totalHeight > view.height then
				if event.y == view.y then
					parent:emit({ type = 'scroll_up'})
				elseif event.y == view.y + view.height - 1 then
					parent:emit({ type = 'scroll_down'})
				else
					local percent = (event.y - view.y) / (view.height - 2)
					local y = math.floor((view.totalHeight - view.height) * percent)
					parent :emit({ type = 'scroll_to', offset = y })
				end
			end
			return true
		end
	end
end

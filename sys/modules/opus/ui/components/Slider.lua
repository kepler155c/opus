local class  = require('opus.class')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local colors = _G.colors

UI.Slider = class(UI.Window)
UI.Slider.defaults = {
	UIElement = 'Slider',
	height = 1,
	barChar = UI.extChars and '\140' or '-',
	barColor = colors.gray,
	sliderChar = UI.extChars and '\143' or '\124',
	sliderColor = colors.blue,
	leftBorder = '\141',
	rightBorder = '\142',
	value = 0,
	min = 0,
	max = 100,
	event = 'slider_update',
}
function UI.Slider:draw()
	local range = self.max - self.min
	local perc = (self.value - self.min) / range
	local progress = Util.clamp(1 + self.width * perc, 1, self.width)

	local bar = { }
	for i = 1, self.width do
		local filler =
			i == 1 and self.leftBorder or
			i == self.width and self.rightBorder or
			self.barChar

			table.insert(bar, filler)
	end
	self:write(1, 1, table.concat(bar), nil, self.barColor)
	self:write(progress, 1, self.sliderChar, nil, self.sliderColor)
end

function UI.Slider:eventHandler(event)
	if event.type == "mouse_down" or event.type == "mouse_drag" then
		local range = self.max - self.min
		local i = (event.x - 1) / (self.width - 1)
		self.value = self.min + (i * range)
		self:emit({ type = self.event, value = self.value, element = self })
		self:draw()
	end
end

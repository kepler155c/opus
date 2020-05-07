local class  = require('opus.class')
local UI     = require('opus.ui')
local Util   = require('opus.util')

UI.Slider = class(UI.Window)
UI.Slider.defaults = {
	UIElement = 'Slider',
	height = 1,
	barChar = UI.extChars and '\140' or '-',
	barColor = 'gray',
	sliderChar = UI.extChars and '\143' or '\124',
	sliderColor = 'blue',
	sliderFocusColor = 'lightBlue',
	leftBorder = UI.extChars and '\141' or '\124',
	rightBorder = UI.extChars and '\142' or '\124',
	labelWidth = 0,
	value = 0,
	min = 0,
	max = 100,
	event = 'slider_update',
	transform = function(v) return Util.round(v, 2) end,
	accelerators = {
		right = 'slide_right',
		left = 'slide_left',
	}
}
function UI.Slider:setValue(value)
	self.value = self.transform(tonumber(value) or self.min)
	self.value = Util.clamp(self.value, self.min, self.max)
	self:draw()
end

function UI.Slider:reset() -- form support
	self.value = self.min
	self:draw()
end

function UI.Slider:focus()
	self:draw()
end

function UI.Slider:getSliderWidth()
	local labelWidth = self.labelWidth > 0 and self.labelWidth + 1
	return self.width - (labelWidth or 0)
end

function UI.Slider:draw()
	local labelWidth = self.labelWidth > 0 and self.labelWidth + 1
	local width = self.width - (labelWidth or 0)
	local range = self.max - self.min
	local perc = (self.value - self.min) / range
	local progress = Util.clamp(1 + width * perc, 1, width)

	local bar = self.leftBorder .. string.rep(self.barChar, width - 2) .. self.rightBorder
	self:write(1, 1, bar, nil, self.barColor)
	self:write(progress, 1, self.sliderChar, nil, self.focused and self.sliderFocusColor or self.sliderColor)
	if labelWidth then
		self:write(self.width - labelWidth + 2, 1, Util.widthify(tostring(self.value), self.labelWidth))
	end
end

function UI.Slider:eventHandler(event)
	if event.type == "mouse_down" or event.type == "mouse_drag" then
		local pos = event.x - 1
		if event.type == 'mouse_down' then
			self.anchor = event.x - 1
		else
			pos = self.anchor + event.dx
		end
		local range = self.max - self.min
		local i = pos / (self:getSliderWidth() - 1)
		self:setValue(self.min + (i * range))
		self:emit({ type = self.event, value = self.value, element = self })
		return true

	elseif event.type == 'slide_left' or event.type == 'slide_right' then
		local range = self.max - self.min
		local step = range / (self:getSliderWidth() - 1)
		if event.type == 'slide_left' then
			self:setValue(self.value - step)
		else
			self:setValue(self.value + step)
		end
		self:emit({ type = self.event, value = self.value, element = self })
		return true
	end
end

function UI.Slider.example()
	return UI.Window {
		UI.Slider {
			y = 2, x = 2, ex = -2,
			min = 0, max = 1,
		},
		UI.Slider {
			y = 4, x = 2, ex = -2,
			min = -1, max = 1,
			labelWidth = 5,
		},
		UI.Slider {
			y = 6, x = 2, ex = -2,
			min = 0, max = 100,
			labelWidth = 3,
			transform = math.floor,
		},
	}
end

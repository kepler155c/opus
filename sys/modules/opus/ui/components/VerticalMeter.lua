local class = require('opus.class')
local UI    = require('opus.ui')

local colors = _G.colors

UI.VerticalMeter = class(UI.Window)
UI.VerticalMeter.defaults = {
	UIElement = 'VerticalMeter',
	backgroundColor = colors.gray,
	meterColor = colors.lime,
	width = 1,
	value = 0,
}
function UI.VerticalMeter:draw()
	local height = self.height - math.ceil(self.value / 100 * self.height)
	self:clear()
	self:clearArea(1, height + 1, self.width, self.height, self.meterColor)
end

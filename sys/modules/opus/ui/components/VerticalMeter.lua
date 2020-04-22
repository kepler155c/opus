local class = require('opus.class')
local UI    = require('opus.ui')

UI.VerticalMeter = class(UI.Window)
UI.VerticalMeter.defaults = {
	UIElement = 'VerticalMeter',
	backgroundColor = 'gray',
	meterColor = 'lime',
	width = 1,
	value = 0,
}
function UI.VerticalMeter:draw()
	local height = self.height - math.ceil(self.value / 100 * self.height)
	self:clear()
	self:clearArea(1, height + 1, self.width, self.height, self.meterColor)
end

function UI.VerticalMeter.example()
	return UI.VerticalMeter {
		x = 2, width = 3, y = 2, ey = -2,
		focus = function() end,
		enable = function(self)
			require('opus.event').onInterval(.25, function()
				self.value = self.value == 100 and 0 or self.value + 5
				self:draw()
				self:sync()
			end)
			return UI.VerticalMeter.enable(self)
		end
	}
end

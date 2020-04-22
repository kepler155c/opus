local class = require('opus.class')
local UI    = require('opus.ui')

UI.ProgressBar = class(UI.Window)
UI.ProgressBar.defaults = {
	UIElement = 'ProgressBar',
	backgroundColor = 'gray',
	height = 1,
	progressColor = 'lime',
	progressChar = UI.extChars and '\153' or ' ',
	fillChar = ' ',
	fillColor = 'gray',
	textColor = 'green',
	value = 0,
}
function UI.ProgressBar:draw()
	local width = math.ceil(self.value / 100 * self.width)

	self:fillArea(width + 1, 1, self.width - width, self.height, self.fillChar, nil, self.fillColor)
	self:fillArea(1, 1, width, self.height, self.progressChar, self.progressColor)
end

function UI.ProgressBar.example()
	return UI.ProgressBar {
		x = 2, ex = -2, y = 2, height = 2,
		focus = function() end,
		enable = function(self)
			require('opus.event').onInterval(.25, function()
				self.value = self.value == 100 and 0 or self.value + 5
				self:draw()
				self:sync()
			end)
			return UI.ProgressBar.enable(self)
		end
	}
end

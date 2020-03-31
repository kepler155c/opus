local class = require('opus.class')
local UI    = require('opus.ui')

local colors = _G.colors

UI.ProgressBar = class(UI.Window)
UI.ProgressBar.defaults = {
	UIElement = 'ProgressBar',
	backgroundColor = colors.gray,
	height = 1,
	progressColor = colors.lime,
	progressChar = UI.extChars and '\153' or ' ',
	fillChar = ' ',
	fillColor = colors.gray,
	textColor = colors.green,
	value = 0,
}
function UI.ProgressBar:draw()
	local width = math.ceil(self.value / 100 * self.width)

	local filler = string.rep(self.fillChar, self.width)
	local progress = string.rep(self.progressChar, width)

	for i = 1, self.height do
		self:write(1, i, filler, nil, self.fillColor)
		self:write(1, i, progress, self.progressColor)
	end
end

function UI.ProgressBar.example()
	return UI.ProgressBar {
		x = 2, ex = -2, y = 2,
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

local class = require('class')
local UI    = require('ui')

local colors = _G.colors

UI.ProgressBar = class(UI.Window)
UI.ProgressBar.defaults = {
	UIElement = 'ProgressBar',
	progressColor = colors.lime,
	backgroundColor = colors.gray,
	height = 1,
	value = 0,
}
function UI.ProgressBar:draw()
	self:clear()
	local width = math.ceil(self.value / 100 * self.width)
	self:clearArea(1, 1, width, self.height, self.progressColor)
end

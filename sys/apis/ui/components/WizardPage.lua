local class = require('class')
local UI    = require('ui')

local colors = _G.colors

UI.WizardPage = class(UI.ActiveLayer)
UI.WizardPage.defaults = {
	UIElement = 'WizardPage',
	backgroundColor = colors.cyan,
	ey = -2,
}

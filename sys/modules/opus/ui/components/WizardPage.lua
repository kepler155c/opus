local class = require('opus.class')
local UI    = require('opus.ui')

local colors = _G.colors

UI.WizardPage = class(UI.ActiveLayer)
UI.WizardPage.defaults = {
	UIElement = 'WizardPage',
	backgroundColor = colors.cyan,
	ey = -2,
}

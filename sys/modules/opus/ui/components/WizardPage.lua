local class = require('opus.class')
local UI    = require('opus.ui')

UI.WizardPage = class(UI.Window)
UI.WizardPage.defaults = {
	UIElement = 'WizardPage',
	ey = -2,
}
function UI.WizardPage.validate()
	return true
end

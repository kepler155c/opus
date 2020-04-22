local class  = require('opus.class')
local UI     = require('opus.ui')

UI.Dialog = class(UI.SlideOut)
UI.Dialog.defaults = {
	UIElement = 'Dialog',
	height = 7,
	noFill = true,
	okEvent ='dialog_ok',
	cancelEvent = 'dialog_cancel',
}
function UI.Dialog:postInit()
	self.y = -self.height
	self.titleBar = UI.TitleBar({ event = self.cancelEvent, title = self.title })
end

function UI.Dialog:eventHandler(event)
	if event.type == 'dialog_cancel' then
		self:hide()
	end
	return UI.SlideOut.eventHandler(self, event)
end

function UI.Dialog.example()
	return UI.Dialog {
		title = 'Enter Starting Level',
		height = 7,
		form = UI.Form {
			y = 3, x = 2, height = 4,
			event = 'setStartLevel',
			cancelEvent = 'slide_hide',
			text = UI.Text {
				x = 5, y = 1, width = 20,
				textColor = 'gray',
			},
			textEntry = UI.TextEntry {
				formKey = 'level',
				x = 15, y = 1, width = 7,
			},
		},
		statusBar = UI.StatusBar(),
		enable = function(self)
			require('opus.event').onTimeout(0, function()
				self:show()
				self:sync()
			end)
		end,
	}
end

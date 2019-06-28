local Canvas = require('opus.ui.canvas')
local class  = require('opus.class')
local UI     = require('opus.ui')

local colors = _G.colors

UI.Dialog = class(UI.SlideOut)
UI.Dialog.defaults = {
	UIElement = 'Dialog',
	height = 7,
	textColor = colors.black,
	backgroundColor = colors.white,
	okEvent ='dialog_ok',
	cancelEvent = 'dialog_cancel',
}
function UI.Dialog:postInit()
	self.y = -self.height
	self.titleBar = UI.TitleBar({ event = self.cancelEvent, title = self.title })
end

function UI.Dialog:show(...)
	local canvas = self.parent:getCanvas()
	self.oldPalette = canvas.palette
	canvas:applyPalette(Canvas.darkPalette)
	UI.SlideOut.show(self, ...)
end

function UI.Dialog:hide(...)
	self.parent:getCanvas().palette = self.oldPalette
	UI.SlideOut.hide(self, ...)
	self.parent:draw()
end

function UI.Dialog:eventHandler(event)
	if event.type == 'dialog_cancel' then
		self:hide()
	end
	return UI.SlideOut.eventHandler(self, event)
end

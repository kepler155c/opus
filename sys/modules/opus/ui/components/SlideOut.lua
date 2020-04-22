local class = require('opus.class')
local UI    = require('opus.ui')

UI.SlideOut = class(UI.Window)
UI.SlideOut.defaults = {
	UIElement = 'SlideOut',
	transitionHint = 'expandUp',
	modal = true,
}
function UI.SlideOut:enable()
end

function UI.SlideOut:toggle()
	if self.enabled then
		self:hide()
	else
		self:show()
	end
end

function UI.SlideOut:show(...)
	UI.Window.enable(self, ...)
	self:draw()
	self:focusFirst()
end

function UI.SlideOut:hide()
	self:disable()
end

function UI.SlideOut:draw()
	if not self.noFill then
		self:fillArea(1, 1, self.width, self.height, string.rep('\127', self.width), 'black', 'gray')
	end
	self:drawChildren()
end

function UI.SlideOut:eventHandler(event)
	if event.type == 'slide_show' then
		self:show()
		return true

	elseif event.type == 'slide_hide' then
		self:hide()
		return true
	end
end

function UI.SlideOut.example()
	return UI.Window {
		y = 3,
		backgroundColor = 2048,
		button = UI.Button {
			x = 2, y = 5,
			text = 'show',
		},
		slideOut = UI.SlideOut {
			backgroundColor = 16,
			y = -7, height = 4, x = 3, ex = -3,
			titleBar = UI.TitleBar {
				title = 'test',
			},
			button = UI.Button {
				x = 2, y = 2,
				text = 'hide',
				--visualize = true,
			},
		},
		eventHandler = function (self, event)
			if event.type == 'button_press' then
				self.slideOut:toggle()
			end
		end,
	}
end

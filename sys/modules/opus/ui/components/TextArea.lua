local class = require('opus.class')
local UI    = require('opus.ui')

UI.TextArea = class(UI.Viewport)
UI.TextArea.defaults = {
	UIElement = 'TextArea',
	marginRight = 2,
	value = '',
	showScrollBar = true,
}
function UI.TextArea:setText(text)
	self:reset()
	self.value = text
	self:draw()
end

function UI.TextArea:focus()
	-- allow keyboard scrolling
end

function UI.TextArea:draw()
	self:clear()
	self.cursorX, self.cursorY = 1, 1
	self:print(self.value)
	self:drawChildren()
end

function UI.TextArea.example()
	return UI.Window {
		backgroundColor = 2048,
		t1 = UI.TextArea {
			ey = 3,
			value = 'sample text\nabc'
		},
		t2 = UI.TextArea {
			y = 5,
			value = [[1
2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26
3
4
5
6
7
8]]
		}
	}
end
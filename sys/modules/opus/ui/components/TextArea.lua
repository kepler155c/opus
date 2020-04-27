local class = require('opus.class')
local UI    = require('opus.ui')

UI.TextArea = class(UI.Viewport)
UI.TextArea.defaults = {
	UIElement = 'TextArea',
	marginRight = 2,
	value = '',
	showScrollBar = true,
}
function UI.TextArea:setValue(text)
	self:reset()
	self.value = text
	self:draw()
end
UI.TextArea.setText = UI.TextArea.setValue -- deprecate

function UI.TextArea.focus()
	-- allow keyboard scrolling
end

function UI.TextArea:draw()
	self:clear()
	self:print(self.value)
	self:drawChildren()
end

function UI.TextArea.example()
	local Ansi = require('opus.ansi')
	return UI.Window {
		backgroundColor = 2048,
		t1 = UI.TextArea {
			ey = 3,
			value = 'sample text\nabc'
		},
		t2 = UI.TextArea {
			y = 5,
			backgroundColor = 'green',
			value = string.format([[now %%is the %stime %sfor%s all good men to come to the aid of their country.
1
2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26
3
4
5
6
7
8]], Ansi.yellow, Ansi.onred, Ansi.reset),
		}
	}
end
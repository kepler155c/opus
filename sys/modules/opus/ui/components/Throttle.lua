local class = require('opus.class')
local UI    = require('opus.ui')

local colors = _G.colors
local os     = _G.os

UI.Throttle = class(UI.Window)
UI.Throttle.defaults = {
	UIElement = 'Throttle',
	backgroundColor = colors.gray,
	bordercolor = colors.cyan,
	height = 4,
	width = 10,
	timeout = .075,
	ctr = 0,
	image = {
		'  //)    (O )~@ &~&-( ?Q        ',
		'  //)    (O )- @  \\-( ?)  &&    ',
		'  //)    (O ), @  \\-(?)     &&  ',
		'  //)    (O ). @  \\-d )      (@ '
	}
}
function UI.Throttle:layout()
	self.x = math.ceil((self.parent.width - self.width) / 2)
	self.y = math.ceil((self.parent.height - self.height) / 2)
	self:reposition(self.x, self.y, self.width, self.height)
end

function UI.Throttle:enable()
	self.c = os.clock()
	self.ctr = 0
end

function UI.Throttle:update()
	local cc = os.clock()
	if cc > self.c + self.timeout then
		os.sleep(0)
		self.c = os.clock()
		self.enabled = true
		self:clear(self.borderColor)
		local image = self.image[self.ctr + 1]
		local width = self.width - 2
		for i = 0, #self.image do
			self:write(2, i + 1, image:sub(width * i + 1, width * i + width),
				self.backgroundColor, self.textColor)
		end

		self.ctr = (self.ctr + 1) % #self.image

		self:sync()
	end
end

function UI.Throttle.example()
	return UI.Window {
		button1 = UI.Button {
			x = 2, y = 2,
			text = 'Test',
		},
		throttle = UI.Throttle {
			textColor = colors.yellow,
			borderColor = colors.green,
		},
		eventHandler = function (self, event)
			if event.type == 'button_press' then
				for _ = 1, 40 do
					self.throttle:update()
					os.sleep(.05)
				end
				self.throttle:disable()
			end
		end,
	}
end

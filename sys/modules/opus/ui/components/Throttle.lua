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
function UI.Throttle:setParent()
	self.x = math.ceil((self.parent.width - self.width) / 2)
	self.y = math.ceil((self.parent.height - self.height) / 2)
	UI.Window.setParent(self)
end

function UI.Throttle:enable()
	self.c = os.clock()
	self.enabled = false
end

function UI.Throttle:disable()
	if self.canvas then
		self.enabled = false
		self.canvas:removeLayer()
		self.canvas = nil
		self.ctr = 0
	end
end

function UI.Throttle:update()
	local cc = os.clock()
	if cc > self.c + self.timeout then
		os.sleep(0)
		self.c = os.clock()
		self.enabled = true
		if not self.canvas then
			self.canvas = self:addLayer(self.backgroundColor, self.borderColor)
			self.canvas:setVisible(true)
			self:clear(self.borderColor)
		end
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

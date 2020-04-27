local class = require('opus.class')
local UI    = require('opus.ui')
local Util  = require('opus.util')

local lookup = '0123456789abcdef'

-- handle files produced by Paint
UI.Image = class(UI.Window)
UI.Image.defaults = {
	UIElement = 'Image',
	event = 'button_press',
}
function UI.Image:postInit()
	if self.filename then
		self.image = Util.readLines(self.filename)
	end

	if self.image and not (self.height or self.ey) then
		self.height = #self.image
	end
	if self.image and not (self.width or self.ex) then
		for i = 1, self.height do
			self.width = math.max(self.width or 0, #self.image[i])
		end
	end
end

function UI.Image:draw()
	self:clear()
	if self.image then
		for y = 1, #self.image do
			local line = self.image[y]
			for x = 1, #line do
				local ch = lookup:find(line:sub(x, x))
				if ch then
					self:write(x, y, ' ', 2 ^ (ch - 1))
				end
			end
		end
	end
	self:drawChildren()
end

function UI.Image:setImage(image)
	self.image = image
end

function UI.Image.example()
	return UI.Image {
		backgroundColor = 'primary',
		filename = 'test.paint',
	}
end

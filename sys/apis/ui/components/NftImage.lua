local class = require('class')
local UI    = require('ui')

UI.NftImage = class(UI.Window)
UI.NftImage.defaults = {
	UIElement = 'NftImage',
	event = 'button_press',
}
function UI.NftImage:setParent()
	if self.image then
		self.height = self.image.height
	end
	if self.image and not self.width then
		self.width = self.image.width
	end
	UI.Window.setParent(self)
end

function UI.NftImage:draw()
	if self.image then
		for y = 1, self.image.height do
			for x = 1, #self.image.text[y] do
				self:write(x, y, self.image.text[y][x], self.image.bg[y][x], self.image.fg[y][x])
			end
		end
	else
		self:clear()
	end
end

function UI.NftImage:setImage(image)
	self.image = image
end

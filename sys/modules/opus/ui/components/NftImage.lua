local class = require('opus.class')
local UI    = require('opus.ui')

UI.NftImage = class(UI.Window)
UI.NftImage.defaults = {
	UIElement = 'NftImage',
}
function UI.NftImage:postInit()
	if self.image and not (self.ey or self.height) then
		self.height = self.image.height
	end
	if self.image and not (self.ex or self.width) then
		self.width = self.image.width
	end
end

function UI.NftImage:draw()
	self:clear()

	if self.image then
		-- due to blittle, the background and foreground transparent
		-- color is the same as the background color
		local bg = self:getProperty('backgroundColor')
		for y = 1, self.image.height do
			for x = 1, #self.image.text[y] do
				self:write(x, y, self.image.text[y][x], self.image.bg[y][x], self.image.fg[y][x] or bg)
			end
		end
	end
end

function UI.NftImage:setImage(image)
	self.image = image
end

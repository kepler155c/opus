local class = require('opus.class')
local UI    = require('opus.ui')

UI.Image = class(UI.Window)
UI.Image.defaults = {
	UIElement = 'Image',
	event = 'button_press',
}
function UI.Image:setParent()
	if self.image then
		self.height = #self.image
	end
	if self.image and not self.width then
		self.width = #self.image[1]
	end
	UI.Window.setParent(self)
end

function UI.Image:draw()
	self:clear()
	if self.image then
		for y = 1, #self.image do
			local line = self.image[y]
			for x = 1, #line do
				local ch = line[x]
				if type(ch) == 'number' then
					if ch > 0 then
						self:write(x, y, ' ', ch)
					end
				else
					self:write(x, y, ch)
				end
			end
		end
	end
end

function UI.Image:setImage(image)
	self.image = image
end

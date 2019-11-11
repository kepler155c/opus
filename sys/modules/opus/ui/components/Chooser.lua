local class = require('opus.class')
local UI    = require('opus.ui')
local Util  = require('opus.util')

local colors = _G.colors

UI.Chooser = class(UI.Window)
UI.Chooser.defaults = {
	UIElement = 'Chooser',
	choices = { },
	nochoice = 'Select',
	backgroundFocusColor = colors.lightGray,
	textInactiveColor = colors.gray,
	leftIndicator = UI.extChars and '\17' or '<',
	rightIndicator = UI.extChars and '\16' or '>',
	height = 1,
}
function UI.Chooser:setParent()
	if not self.width and not self.ex then
		self.width = 1
		for _,v in pairs(self.choices) do
			if #v.name > self.width then
				self.width = #v.name
			end
		end
		self.width = self.width + 4
	end
	UI.Window.setParent(self)
end

function UI.Chooser:draw()
	local bg = self.backgroundColor
	if self.focused then
		bg = self.backgroundFocusColor
	end
	local fg = self.inactive and self.textInactiveColor or self.textColor
	local choice = Util.find(self.choices, 'value', self.value)
	local value = self.nochoice
	if choice then
		value = choice.name
	end
	self:write(1, 1, self.leftIndicator, self.backgroundColor, colors.black)
	self:write(2, 1, ' ' .. Util.widthify(tostring(value), self.width-4) .. ' ', bg, fg)
	self:write(self.width, 1, self.rightIndicator, self.backgroundColor, colors.black)
end

function UI.Chooser:focus()
	self:draw()
end

function UI.Chooser:eventHandler(event)
	if event.type == 'key' then
		if event.key == 'right' or event.key == 'space' then
			local _,k = Util.find(self.choices, 'value', self.value)
			local choice
			if not k then k = 1 end
			if k and k < #self.choices then
				choice = self.choices[k+1]
			else
				choice = self.choices[1]
			end
			self.value = choice.value
			self:emit({ type = 'choice_change', value = self.value, element = self, choice = choice })
			self:draw()
			return true
		elseif event.key == 'left' then
			local _,k = Util.find(self.choices, 'value', self.value)
			local choice
			if k and k > 1 then
				choice = self.choices[k-1]
			else
				choice = self.choices[#self.choices]
			end
			self.value = choice.value
			self:emit({ type = 'choice_change', value = self.value, element = self, choice = choice })
			self:draw()
			return true
		end
	elseif event.type == 'mouse_click' or event.type == 'mouse_doubleclick' then
		if event.x == 1 then
			self:emit({ type = 'key', key = 'left' })
			return true
		elseif event.x == self.width then
			self:emit({ type = 'key', key = 'right' })
			return true
		end
	end
end

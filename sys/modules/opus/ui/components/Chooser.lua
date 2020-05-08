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
	leftIndicator = UI.extChars and '\171' or '<',
	rightIndicator = UI.extChars and '\187' or '>',
	height = 1,
	accelerators = {
		[ ' ' ] = 'choice_next',
		right = 'choice_next',
		left  = 'choice_prev',
	}
}
function UI.Chooser:layout()
	if not self.width and not self.ex then
		self.width = 1
		for _,v in pairs(self.choices) do
			if #v.name > self.width then
				self.width = #v.name
			end
		end
		self.width = self.width + 4
	end
	UI.Window.layout(self)
end

function UI.Chooser:draw()
	local bg = self.focused and self.backgroundFocusColor or self.backgroundColor
	local fg = self.inactive and self.textInactiveColor or self.textColor
	local choice = Util.find(self.choices, 'value', self.value)
	local value = choice and choice.name or self.nochoice

	self:write(1, 1, self.leftIndicator, self.backgroundColor, colors.black)
	self:write(2, 1, ' ' .. Util.widthify(tostring(value), self.width - 4) .. ' ', bg, fg)
	self:write(self.width, 1, self.rightIndicator, self.backgroundColor, colors.black)
end

function UI.Chooser:focus()
	self:draw()
end

function UI.Chooser:eventHandler(event)
	if event.type == 'choice_next' then
		local _,k = Util.find(self.choices, 'value', self.value)
		local choice
		if not k then k = 0 end
		if k and k < #self.choices then
			choice = self.choices[k + 1]
		else
			choice = self.choices[1]
		end
		self.value = choice.value
		self:emit({ type = 'choice_change', value = self.value, element = self, choice = choice })
		self:draw()
		return true

	elseif event.type == 'choice_prev' then
		local _,k = Util.find(self.choices, 'value', self.value)
		local choice
		if k and k > 1 then
			choice = self.choices[k - 1]
		else
			choice = self.choices[#self.choices]
		end
		self.value = choice.value
		self:emit({ type = 'choice_change', value = self.value, element = self, choice = choice })
		self:draw()
		return true

	elseif event.type == 'mouse_click' or event.type == 'mouse_doubleclick' then
		if event.x == 1 then
			self:emit({ type = 'choice_prev' })
			return true
		elseif event.x == self.width then
			self:emit({ type = 'choice_next' })
			return true
		end
	end
end

function UI.Chooser.example()
	return UI.Window {
		a = UI.Chooser {
			x = 2, y = 2,
			choices = {
				{ name = 'choice1', value = 'value1' },
				{ name = 'choice2', value = 'value2' },
				{ name = 'choice3', value = 'value3' },
			},
			value = 'value2',
		},
		b = UI.Chooser {
			x = 2, y = 4,
			choices = {
				{ name = 'choice1', value = 'value1' },
				{ name = 'choice2', value = 'value2' },
				{ name = 'choice3', value = 'value3' },
			},
		}
	}
end

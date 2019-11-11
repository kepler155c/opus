local class = require('opus.class')
local UI    = require('opus.ui')

local colors = _G.colors
local _rep   = string.rep
local _sub   = string.sub

-- For manipulating text in a fixed width string
local SB = class()
function SB:init(width)
	self.width = width
	self.buf = _rep(' ', width)
end
function SB:insert(x, str, width)
	if x < 1 then
		x = self.width + x + 1
	end
	width = width or #str
	if x + width - 1 > self.width then
		width = self.width - x
	end
	if width > 0 then
		self.buf = _sub(self.buf, 1, x - 1) .. _sub(str, 1, width) .. _sub(self.buf, x + width)
	end
end
function SB:fill(x, ch, width)
	width = width or self.width - x + 1
	self:insert(x, _rep(ch, width))
end
function SB:center(str)
	self:insert(math.max(1, math.ceil((self.width - #str + 1) / 2)), str)
end
function SB:get()
	return self.buf
end

UI.TitleBar = class(UI.Window)
UI.TitleBar.defaults = {
	UIElement = 'TitleBar',
	height = 1,
	textColor = colors.white,
	backgroundColor = colors.cyan,
	title = '',
	frameChar = UI.extChars and '\140' or '-',
	closeInd = UI.extChars and '\215' or '*',
}
function UI.TitleBar:draw()
	local sb = SB(self.width)
	sb:fill(2, self.frameChar, sb.width - 3)
	sb:center(string.format(' %s ', self.title))
	if self.previousPage or self.event then
		sb:insert(-1, self.closeInd)
	else
		sb:insert(-2, self.frameChar)
	end
	self:write(1, 1, sb:get())
end

function UI.TitleBar:eventHandler(event)
	if event.type == 'mouse_click' then
		if (self.previousPage or self.event) and event.x == self.width then
			if self.event then
				self:emit({ type = self.event, element = self })
			elseif type(self.previousPage) == 'string' or
				 type(self.previousPage) == 'table' then
				UI:setPage(self.previousPage)
			else
				UI:setPreviousPage()
			end
			return true
		end
	end
end

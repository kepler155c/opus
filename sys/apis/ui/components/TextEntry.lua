local class = require('class')
local UI    = require('ui')
local Util  = require('util')

local colors = _G.colors
local os     = _G.os
local _rep   = string.rep

UI.TextEntry = class(UI.Window)
UI.TextEntry.defaults = {
	UIElement = 'TextEntry',
	value = '',
	shadowText = '',
	focused = false,
	textColor = colors.white,
	shadowTextColor = colors.gray,
	backgroundColor = colors.black, -- colors.lightGray,
	backgroundFocusColor = colors.black, --lightGray,
	height = 1,
	limit = 6,
	pos = 0,
	accelerators = {
		[ 'control-c' ] = 'copy',
	}
}
function UI.TextEntry:postInit()
	self.value = tostring(self.value)
end

function UI.TextEntry:setValue(value)
	self.value = value
end

function UI.TextEntry:setPosition(pos)
	self.pos = pos
end

function UI.TextEntry:updateScroll()
	if not self.scroll then
		self.scroll = 0
	end

	if not self.pos then
		self.pos = #tostring(self.value)
		self.scroll = 0
	elseif self.pos > #tostring(self.value) then
		self.pos = #tostring(self.value)
		self.scroll = 0
	end

	if self.pos - self.scroll > self.width - 2 then
		self.scroll = self.pos - (self.width - 2)
	elseif self.pos < self.scroll then
		self.scroll = self.pos
	end
end

function UI.TextEntry:draw()
	local bg = self.backgroundColor
	local tc = self.textColor
	if self.focused then
		bg = self.backgroundFocusColor
	end

	self:updateScroll()
	local text = tostring(self.value)
	if #text > 0 then
		if self.scroll and self.scroll > 0 then
			text = text:sub(1 + self.scroll)
		end
		if self.mask then
			text = _rep('*', #text)
		end
	else
		tc = self.shadowTextColor
		text = self.shadowText
	end

	self:write(1, 1, ' ' .. Util.widthify(text, self.width - 2) .. ' ', bg, tc)
	if self.focused then
		self:setCursorPos(self.pos-self.scroll+2, 1)
	end
end

function UI.TextEntry:reset()
	self.pos = 0
	self.value = ''
	self:draw()
	self:updateCursor()
end

function UI.TextEntry:updateCursor()
	self:updateScroll()
	self:setCursorPos(self.pos-self.scroll+2, 1)
end

function UI.TextEntry:focus()
	self:draw()
	if self.focused then
		self:setCursorBlink(true)
	else
		self:setCursorBlink(false)
	end
end

--[[
	A few lines below from theoriginalbit
	http://www.computercraft.info/forums2/index.php?/topic/16070-read-and-limit-length-of-the-input-field/
--]]
function UI.TextEntry:eventHandler(event)
	if event.type == 'key' then
		local ch = event.key
		if ch == 'left' then
			if self.pos > 0 then
				self.pos = math.max(self.pos-1, 0)
				self:draw()
			end
		elseif ch == 'right' then
			local input = tostring(self.value)
			if self.pos < #input then
				self.pos = math.min(self.pos+1, #input)
				self:draw()
			end
		elseif ch == 'home' then
			self.pos = 0
			self:draw()
		elseif ch == 'end' then
			self.pos = #tostring(self.value)
			self:draw()
		elseif ch == 'backspace' then
			if self.pos > 0 then
				local input = tostring(self.value)
				self.value = input:sub(1, self.pos-1) .. input:sub(self.pos+1)
				self.pos = self.pos - 1
				self:draw()
				self:emit({ type = 'text_change', text = self.value, element = self })
			end
		elseif ch == 'delete' then
			local input = tostring(self.value)
			if self.pos < #input then
				self.value = input:sub(1, self.pos) .. input:sub(self.pos+2)
				self:draw()
				self:emit({ type = 'text_change', text = self.value, element = self })
			end
		elseif #ch == 1 then
			local input = tostring(self.value)
			if #input < self.limit then
				self.value = input:sub(1, self.pos) .. ch .. input:sub(self.pos+1)
				self.pos = self.pos + 1
				self:draw()
				self:emit({ type = 'text_change', text = self.value, element = self })
			end
		else
			return false
		end
		return true

	elseif event.type == 'copy' then
		os.queueEvent('clipboard_copy', self.value)

	elseif event.type == 'paste' then
		local input = tostring(self.value)
		local text = event.text
		if #input + #text > self.limit then
			text = text:sub(1, self.limit-#input)
		end
		self.value = input:sub(1, self.pos) .. text .. input:sub(self.pos+1)
		self.pos = self.pos + #text
		self:draw()
		self:updateCursor()
		self:emit({ type = 'text_change', text = self.value, element = self })
		return true

	elseif event.type == 'mouse_click' then
		if self.focused and event.x > 1 then
			self.pos = event.x + self.scroll - 2
			self:updateCursor()
			return true
		end
	elseif event.type == 'mouse_rightclick' then
		local input = tostring(self.value)
		if #input > 0 then
			self:reset()
			self:emit({ type = 'text_change', text = self.value, element = self })
		end
	end

	return false
end

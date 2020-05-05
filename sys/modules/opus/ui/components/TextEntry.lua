local class = require('opus.class')
local entry = require('opus.entry')
local UI    = require('opus.ui')
local Util  = require('opus.util')

local _rep   = string.rep

local function transform(directive)
	local transforms = {
		lowercase = string.lower,
		uppercase = string.upper,
		number    = tonumber,
	}
	return transforms[directive]
end

UI.TextEntry = class(UI.Window)
UI.TextEntry.docs = { }
UI.TextEntry.defaults = {
	UIElement = 'TextEntry',
	shadowText = '',
	focused = false,
	textColor = 'white',
	shadowTextColor = 'gray',
	markBackgroundColor = 'gray',
	backgroundColor = 'black',
	backgroundFocusColor = 'black',
	height = 1,
	cursorBlink = true,
	accelerators = {
		[ 'control-c' ] = 'copy',
	}
}
function UI.TextEntry:postInit()
	self.entry = entry({ limit = self.limit, offset = 2, transform = transform(self.transform) })
end

function UI.TextEntry:layout()
	UI.Window.layout(self)
	self.entry.width = self.width - 2
end

function UI.TextEntry:setValue(value)
	self.value = value
	self.entry:unmark()
	self.entry.value = value
	self.entry:updateScroll()
end

function UI.TextEntry:setPosition(pos)
	self.entry.pos = pos
	self.entry.value = self.value -- WHY HERE ?
	self.entry:updateScroll()
end

function UI.TextEntry:draw()
	local bg = self.backgroundColor
	local tc = self.textColor
	if self.focused then
		bg = self.backgroundFocusColor
	end

	local text = tostring(self.value or '')
	if #text > 0 then
		if self.entry.scroll > 0 then
			text = text:sub(1 + self.entry.scroll)
		end
		if self.mask then
			text = _rep('*', #text)
		end
	else
		tc = self.shadowTextColor
		text = self.shadowText
	end

	local ss = self.entry.scroll > 0 and '\183' or ' '
	self:write(2, 1, Util.widthify(text, self.width - 2) .. ' ', bg, tc)
	self:write(1, 1, ss, bg, self.shadowTextColor)

	if self.entry.mark.active then
		local tx = math.max(self.entry.mark.x - self.entry.scroll, 0)
		local tex = self.entry.mark.ex - self.entry.scroll

		if tex > self.width - 2 then -- unsure about this
			tex = self.width - 2 - tx
		end

		if tx ~= tex then
			self:write(tx + 2, 1, text:sub(tx + 1, tex), self.markBackgroundColor, tc)
		end
	end
	if self.focused then
		self:setCursorPos(self.entry.pos - self.entry.scroll + 2, 1)
	end
end

UI.TextEntry.docs.reset = [[reset()
Clears the value and resets the cursor.]]
function UI.TextEntry:reset()
	self.entry:reset()
	self.value = nil--''
	self:draw()
	self:updateCursor()
end

function UI.TextEntry:updateCursor()
	self:setCursorPos(self.entry.pos - self.entry.scroll + 2, 1)
end

function UI.TextEntry:markAll()
	self.entry:markAll()
end

function UI.TextEntry:focus()
	self:draw()
end

function UI.TextEntry:eventHandler(event)
	local text = self.value
	self.entry.value = text
	if event.ie and self.entry:process(event.ie) then
		if self.entry.textChanged then
			local changed = self.value ~= self.entry.value
			self.value = self.entry.value
			self:draw()
			if changed then
				-- we get entry.textChanged when marking is updated
				-- no need to emit in that case
				self:emit({ type = 'text_change', text = self.value, element = self })
			end
		elseif self.entry.posChanged then
			self:updateCursor()
		end
		return true
	end

	return false
end

function UI.TextEntry.example()
	return UI.Window {
		text = UI.TextEntry {
			x = 2, y = 2,
			width = 12,
			limit = 36,
			shadowText = 'normal',
		},
		upper = UI.TextEntry {
			x = 2, y = 3,
			width = 12,
			limit = 36,
			shadowText = 'upper',
			transform = 'uppercase',
		},
		lower = UI.TextEntry {
			x = 2, y = 4,
			width = 12,
			limit = 36,
			shadowText = 'lower',
			transform = 'lowercase',
		},
		number = UI.TextEntry {
			x = 2, y = 5,
			width = 12,
			limit = 36,
			transform = 'number',
			shadowText = 'number',
		},
	}
end

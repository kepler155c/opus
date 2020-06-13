local class = require('opus.class')

local os = _G.os

-- convert value to a string (supporting nils or numbers in value)
local function _val(a)
	return a and tostring(a) or ''
end

local Entry = class()

function Entry:init(args)
	self.pos = 0
	self.scroll = 0
	self.value = args.value
	self.width = args.width or 256
	self.limit = args.limit or 1024
	self.mark = { }
	self.offset = args.offset or 1
	self.transform = args.transform or function(a) return a end
end

function Entry:reset()
	self.pos = 0
	self.scroll = 0
	self.value = nil
	self.mark = { }
end

function Entry:nextWord()
	local value = _val(self.value)
	return select(2, value:find("[%s%p]?%w[%s%p]", self.pos + 1)) or #value
end

function Entry:prevWord()
	local value = _val(self.value)
	local x = #value - (self.pos - 1)
	local _, n = value:reverse():find("[%s%p]?%w[%s%p]", x)
	return n and #value - n + 1 or 0
end

function Entry:updateScroll()
	local ps = self.scroll
	local len = #_val(self.value)
	if self.pos > len then
		self.pos = len
		self.scroll = 0 -- ??
	end
	if self.pos - self.scroll > self.width then
		self.scroll = math.max(0, self.pos - self.width)
	elseif self.pos < self.scroll then
		self.scroll = self.pos
	end
	if self.scroll > 0 then
		if self.scroll + self.width  > len then
			self.scroll = math.max(0, len - self.width)
		end
	end
	if ps ~= self.scroll then
		self.textChanged = true
	end
end

function Entry:copyText(cx, ex)
	-- this should be transformed (ie. if number)
	return _val(self.value):sub(cx + 1, ex)
end

function Entry:insertText(x, text)
	text = tostring(self.transform(text) or '')
	if #text > 0 then
		local value = _val(self.value)
		if #value + #text > self.limit then
			text = text:sub(1, self.limit-#value)
		end
		self.value = self.transform(value:sub(1, x) .. text .. value:sub(x + 1))
		self.pos = self.pos + #text
	end
end

function Entry:deleteText(sx, ex)
	local value = _val(self.value)
	local front = value:sub(1, sx)
	local back = value:sub(ex + 1, #value)
	self.value = self.transform(front .. back)
	self.pos = sx
end

function Entry:moveLeft()
	if self.pos > 0 then
		self.pos = self.pos - 1
		return true
	end
end

function Entry:moveRight()
	if self.pos < #_val(self.value) then
		self.pos = self.pos + 1
		return true
	end
end

function Entry:moveHome()
	if self.pos ~= 0 then
		self.pos = 0
		return true
	end
end

function Entry:moveEnd()
	if self.pos ~= #_val(self.value) then
		self.pos = #_val(self.value)
		return true
	end
end

function Entry:moveTo(ie)
	self.pos = math.max(0, math.min(ie.x + self.scroll - self.offset, #_val(self.value)))
end

function Entry:backspace()
	if self.mark.active then
		self:delete()
	elseif self:moveLeft() then
		self:delete()
	end
end

function Entry:moveWordRight()
	if self.pos < #_val(self.value) then
		self.pos = self:nextWord(self.value, self.pos + 1)
		return true
	end
end

function Entry:moveWordLeft()
	if self.pos > 0 then
		self.pos = self:prevWord(self.value, self.pos - 1) or 0
		return true
	end
end

function Entry:delete()
	if self.mark.active then
		self:deleteText(self.mark.x, self.mark.ex)
	elseif self.pos < #_val(self.value) then
		self:deleteText(self.pos, self.pos + 1)
	end
end

function Entry:cutFromStart()
	if self.pos > 0 then
		local text = self:copyText(1, self.pos)
		self:deleteText(1, self.pos)
		os.queueEvent('clipboard_copy', text)
	end
end

function Entry:cutToEnd()
	local value = _val(self.value)
	if self.pos < #value then
		local text = self:copyText(self.pos, #value)
		self:deleteText(self.pos, #value)
		os.queueEvent('clipboard_copy', text)
	end
end

function Entry:cutNextWord()
	if self.pos < #_val(self.value) then
		local ex = self:nextWord(self.value, self.pos)
		local text = self:copyText(self.pos, ex)
		self:deleteText(self.pos, ex)
		os.queueEvent('clipboard_copy', text)
	end
end

function Entry:cutPrevWord()
	if self.pos > 0 then
		local sx = self:prevWord(self.value, self.pos)
		local text = self:copyText(sx, self.pos)
		self:deleteText(sx, self.pos)
		os.queueEvent('clipboard_copy', text)
	end
end

function Entry:insertChar(ie)
	if self.mark.active then
		self:delete()
	end
	self:insertText(self.pos, ie.ch)
end

function Entry:copy()
	if #_val(self.value) > 0 then
		self.mark.continue = true
		if self.mark.active then
			self:copyMarked()
		else
			os.queueEvent('clipboard_copy', self.value)
		end
	end
end

function Entry:cut()
	if self.mark.active then
		self:copyMarked()
		self:delete()
	end
end

function Entry:copyMarked()
	local text = self:copyText(self.mark.x, self.mark.ex)
	os.queueEvent('clipboard_copy', text)
end

function Entry:paste(ie)
	if #ie.text > 0 then
		if self.mark.active then
			self:delete()
		end
		self:insertText(self.pos, ie.text)
	end
end

function Entry.forcePaste()
	os.queueEvent('clipboard_paste')
end

function Entry:clearLine()
	if #_val(self.value) > 0 then
		self:reset()
	end
end

function Entry:markBegin()
	if not self.mark.active then
		if #_val(self.value) > 0 then
			self.mark.active = true
		end
		self.mark.anchor = { x = self.pos }
	end
end

function Entry:markFinish()
	if self.pos == self.mark.anchor.x then
		self.mark.active = false
	else
		self.mark.x = math.min(self.mark.anchor.x, self.pos)
		self.mark.ex = math.max(self.mark.anchor.x, self.pos)
	end
	self.textChanged = true
	self.mark.continue = self.mark.active
end

function Entry:unmark()
	if self.mark.active then
		self.textChanged = true
		self.mark.active = false
	end
end

function Entry:markAnchor(ie)
	local wasMarking = self.mark.active
	self:unmark()
	self:moveTo(ie)
	self:markBegin()
	self:markFinish()

	self.textChanged = wasMarking
end

function Entry:markLeft()
	self:markBegin()
	if self:moveLeft() then
		self:markFinish()
	else
		self.mark.continue = self.mark.active
	end
end

function Entry:markRight()
	self:markBegin()
	if self:moveRight() then
		self:markFinish()
	else
		self.mark.continue = self.mark.active
	end
end

function Entry:markWord(ie)
	local index = 1
	self:moveTo(ie)
	while true do
		local s, e = _val(self.value):find('%w+', index)
		if not s or s - 1 > self.pos then
			break
		end
		if self.pos >= s - 1 and self.pos < e then
			self.pos = s - 1
			self:markBegin()
			self.pos = e
			self:markFinish()
			self:moveTo(ie)
			break
		end
		index = e + 1
	end
end

function Entry:markNextWord()
	self:markBegin()
	if self:moveWordRight() then
		self:markFinish()
	else
		self.mark.continue = self.mark.active
	end
end

function Entry:markPrevWord()
	self:markBegin()
	if self:moveWordLeft() then
		self:markFinish()
	else
		self.mark.continue = self.mark.active
	end
end

function Entry:markAll()
	if #_val(self.value) > 0 then
		self.mark.anchor = { x = 1 }
		self.mark.active = true
		self.mark.continue = true
		self.mark.x = 0
		self.mark.ex = #_val(self.value)
		self.textChanged = true
	end
end

function Entry:markHome()
	self:markBegin()
	if self:moveHome() then
		self:markFinish()
	else
		self.mark.continue = self.mark.active
	end
end

function Entry:markEnd()
	self:markBegin()
	if self:moveEnd() then
		self:markFinish()
	else
		self.mark.continue = self.mark.active
	end
end

function Entry:markTo(ie)
	self:markBegin()
	self:moveTo(ie)
	self:markFinish()
end

local mappings = {
	[ 'left'                ] = Entry.moveLeft,
	[ 'control-b'           ] = Entry.moveLeft,
	[ 'right'               ] = Entry.moveRight,
	[ 'control-f'           ] = Entry.moveRight,
	[ 'home'                ] = Entry.moveHome,
	[ 'end'                 ] = Entry.moveEnd,
	[ 'control-e'           ] = Entry.moveEnd,
	[ 'mouse_click'         ] = Entry.moveTo,
	[ 'control-right'       ] = Entry.moveWordRight,
	[ 'alt-f'               ] = Entry.moveWordRight,
	[ 'control-left'        ] = Entry.moveWordLeft,
	[ 'alt-b'               ] = Entry.moveWordLeft,

	[ 'backspace'           ] = Entry.backspace,
	[ 'delete'              ] = Entry.delete,
	[ 'char'                ] = Entry.insertChar,
	[ 'mouse_rightclick'    ] = Entry.clearLine,

	[ 'control-c'           ] = Entry.copy,
	[ 'control-u'           ] = Entry.cutFromStart,
	[ 'control-k'           ] = Entry.cutToEnd,
	[ 'control-w'           ] = Entry.cutPrevWord,
	--[ 'control-d'           ] = Entry.cutNextWord,
	[ 'control-x'           ] = Entry.cut,
	[ 'paste'               ] = Entry.paste,
	[ 'control-y'           ] = Entry.forcePaste,  -- well this won't work...

	[ 'mouse_doubleclick'   ] = Entry.markWord,
	[ 'mouse_tripleclick'   ] = Entry.markAll,
	[ 'shift-left'          ] = Entry.markLeft,
	[ 'shift-right'         ] = Entry.markRight,
	[ 'mouse_down'          ] = Entry.markAnchor,
	[ 'mouse_drag'          ] = Entry.markTo,
	[ 'shift-mouse_click'   ] = Entry.markTo,
	[ 'control-a'           ] = Entry.markAll,
	[ 'control-shift-right' ] = Entry.markNextWord,
	[ 'control-shift-left'  ] = Entry.markPrevWord,
	[ 'shift-end'           ] = Entry.markEnd,
	[ 'shift-home'          ] = Entry.markHome,
}

function Entry:process(ie)
	local action = mappings[ie.code]

	self.textChanged = false

	if action then
		local pos = self.pos
		local line = self.value

		local wasMarking = self.mark.continue
		self.mark.continue = false

		action(self, ie)

		if not self.value or #_val(self.value) == 0 then
			self.value = nil
		end

		self.textChanged = self.textChanged or self.value ~= line
		self.posChanged = pos ~= self.pos
		self:updateScroll()

		if not self.mark.continue and wasMarking then
			self:unmark()
		end

		return true
	end
end

return Entry

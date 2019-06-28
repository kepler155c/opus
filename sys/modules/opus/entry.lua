local class = require('opus.class')

local os = _G.os

local Entry = class()

function Entry:init(args)
	self.pos = 0
	self.scroll = 0
	self.value = ''
	self.width = args.width or 256
	self.limit = args.limit or 1024
	self.mark = { }
	self.offset = args.offset or 1
end

function Entry:reset()
	self.pos = 0
	self.scroll = 0
	self.value = ''
	self.mark = { }
end

function Entry:nextWord()
	return select(2, self.value:find("[%s%p]?%w[%s%p]", self.pos + 1)) or #self.value
end

function Entry:prevWord()
	local x = #self.value - (self.pos - 1)
	local _, n = self.value:reverse():find("[%s%p]?%w[%s%p]", x)
	return n and #self.value - n + 1 or 0
end

function Entry:updateScroll()
	local ps = self.scroll
	if self.pos > #self.value then
		self.pos = #self.value
		self.scroll = 0 -- ??
	end
	if self.pos - self.scroll > self.width then
		self.scroll = self.pos - self.width
	elseif self.pos < self.scroll then
		self.scroll = self.pos
	end
	if ps ~= self.scroll then
		self.textChanged = true
	end
end

function Entry:copyText(cx, ex)
	return self.value:sub(cx + 1, ex)
end

function Entry:insertText(x, text)
	if #self.value + #text > self.limit then
		text = text:sub(1, self.limit-#self.value)
	end
	self.value = self.value:sub(1, x) .. text .. self.value:sub(x + 1)
	self.pos = self.pos + #text
end

function Entry:deleteText(sx, ex)
	local front = self.value:sub(1, sx)
	local back = self.value:sub(ex + 1, #self.value)
	self.value = front .. back
	self.pos = sx
end

function Entry:moveLeft()
	if self.pos > 0 then
		self.pos = self.pos - 1
		return true
	end
end

function Entry:moveRight()
	if self.pos < #self.value then
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
	if self.pos ~= #self.value then
		self.pos = #self.value
		return true
	end
end

function Entry:moveTo(ie)
	self.pos = math.max(0, math.min(ie.x + self.scroll - self.offset, #self.value))
end

function Entry:backspace()
	if self.mark.active then
		self:delete()
	elseif self:moveLeft() then
		self:delete()
	end
end

function Entry:moveWordRight()
	if self.pos < #self.value then
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
	elseif self.pos < #self.value then
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
	if self.pos < #self.value then
		local text = self:copyText(self.pos, #self.value)
		self:deleteText(self.pos, #self.value)
		os.queueEvent('clipboard_copy', text)
	end
end

function Entry:cutNextWord()
	if self.pos < #self.value then
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
	if #self.value > 0 then
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

function Entry:clearLine()
	if #self.value > 0 then
		self:reset()
	end
end

function Entry:markBegin()
	if not self.mark.active then
		self.mark.active = true
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
	self:unmark()
	self:moveTo(ie)
	self:markBegin()
	self:markFinish()
end

function Entry:markLeft()
	self:markBegin()
	if self:moveLeft() then
		self:markFinish()
	end
end

function Entry:markRight()
	self:markBegin()
	if self:moveRight() then
		self:markFinish()
	end
end

function Entry:markWord(ie)
	local index = 1
	self:moveTo(ie)
	while true do
		local s, e = self.value:find('%w+', index)
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
	end
end

function Entry:markPrevWord()
	self:markBegin()
	if self:moveWordLeft() then
		self:markFinish()
	end
end

function Entry:markAll()
	if #self.value > 0 then
		self.mark.anchor = { x = 1 }
		self.mark.active = true
		self.mark.continue = true
		self.mark.x = 0
		self.mark.ex = #self.value
		self.textChanged = true
	end
end

function Entry:markHome()
	self:markBegin()
	if self:moveHome() then
		self:markFinish()
	end
end

function Entry:markEnd()
	self:markBegin()
	if self:moveEnd() then
		self:markFinish()
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
--	[ 'control-y'           ] = Entry.paste,  -- well this won't work...

	[ 'mouse_doubleclick'   ] = Entry.markWord,
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

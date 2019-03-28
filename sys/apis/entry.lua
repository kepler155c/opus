local class = require('class')

local os = _G.os

local Entry = class()

function Entry:init(args)
	self.pos = 0
	self.scroll = 0
	self.value = ''
	self.width = args.width
	self.limit = 1024
end

function Entry:reset()
	self.pos = 0
	self.scroll = 0
	self.value = ''
end

local function nextWord(line, cx)
	local result = { line:find("(%w+)", cx) }
	if #result > 1 and result[2] > cx then
		return result[2] + 1
	elseif #result > 0 and result[1] == cx then
		result = { line:find("(%w+)", result[2] + 1) }
		if #result > 0 then
			return result[1]
		end
	end
end

local function prevWord(line, cx)
	local nOffset = 1
	while nOffset <= #line do
		local nNext = line:find("%W%w", nOffset)
		if nNext and nNext < cx then
			nOffset = nNext + 1
		else
			break
		end
	end
	return nOffset - 1 < cx and nOffset - 1
end

function Entry:updateScroll()
	if self.pos - self.scroll > self.width then
		self.scroll = self.pos - (self.width)
	elseif self.pos < self.scroll then
		self.scroll = self.pos
	end
end

local function moveLeft(entry)
	if entry.pos > 0 then
		entry.pos = math.max(entry.pos - 1, 0)
		return true
	end
end

local function moveRight(entry)
	local input = tostring(entry.value)
	if entry.pos < #input then
		entry.pos = math.min(entry.pos + 1, #input)
		return true
	end
end

local function moveStart(entry)
	if entry.pos ~= 0 then
		entry.pos = 0
		return true
	end
end

local function moveEnd(entry)
	if entry.pos ~= #tostring(entry.value) then
		entry.pos = #tostring(entry.value)
		return true
	end
end

local function backspace(entry)
	if entry.pos > 0 then
		local input = tostring(entry.value)
		entry.value = input:sub(1, entry.pos - 1) .. input:sub(entry.pos + 1)
		entry.pos = entry.pos - 1
		return true
	end
end

local function moveWordRight(entry)
	local nx = nextWord(entry.value, entry.pos + 1)
	if nx then
		entry.pos = math.min(nx - 1, #entry.value)
	elseif entry.pos < #entry.value then
		entry.pos = #entry.value
	end
	return true
end

local function moveWordLeft(entry)
	if entry.pos ~= 0 then
		local lx = 1
		while true do
			local nx = nextWord(entry.value, lx)
			if not nx or nx >= entry.pos then
				break
			end
			lx = nx
		end
		if not lx then
			entry.pos = 0
		else
			entry.pos = lx - 1
		end
		return true
	end
end

local function delete(entry)
	local input = tostring(entry.value)
	if entry.pos < #input then
		entry.value = input:sub(1, entry.pos) .. input:sub(entry.pos + 2)
		entry.update = true
		return true
	end
end

-- credit for cut functions to: https://github.com/SquidDev-CC/mbs/blob/master/lib/readline.lua
local function cutFromStart(entry)
	if entry.pos > 0 then
		local input = tostring(entry.value)
		os.queueEvent('clipboard_copy', input:sub(1, entry.pos))
		entry.value = input:sub(entry.pos + 1)
		entry.pos = 0
		return true
	end
end

local function cutToEnd(entry)
	local input = tostring(entry.value)
	if entry.pos < #input then
		os.queueEvent('clipboard_copy', input:sub(entry.pos + 1))
		entry.value = input:sub(1, entry.pos)
		return true
	end
end

local function cutNextWord(entry)
	local input = tostring(entry.value)
	if entry.pos < #input then
		local ex = nextWord(entry.value, entry.pos)
		if ex then
			os.queueEvent('clipboard_copy', input:sub(entry.pos + 1, ex))
			entry.value = input:sub(1, entry.pos) .. input:sub(ex + 1)
			return true
		end
	end
end

local function cutPrevWord(entry)
	if entry.pos > 0 then
		local sx = prevWord(entry.value, entry.pos)
		if sx then
			local input = tostring(entry.value)
			os.queueEvent('clipboard_copy', input:sub(sx + 1, entry.pos))
			entry.value = input:sub(1, sx) .. input:sub(entry.pos + 1)
			entry.pos = sx
			return true
		end
	end
end

local function insertChar(entry, ie)
	local input = tostring(entry.value)
	if #input < entry.limit then
		entry.value = input:sub(1, entry.pos) .. ie.ch .. input:sub(entry.pos + 1)
		entry.pos = entry.pos + 1
		entry.update = true
		return true
	end
end

local function copy(entry)
	os.queueEvent('clipboard_copy', entry.value)
end

local function paste(entry, ie)
	local input = tostring(entry.value)
	if #input + #ie.text > entry.limit then
		ie.text = ie.text:sub(1, entry.limit-#input)
	end
	entry.value = input:sub(1, entry.pos) .. ie.text .. input:sub(entry.pos + 1)
	entry.pos = entry.pos + #ie.text
	return true
end

local function moveCursor(entry, ie)
	-- need starting x passed in instead of hardcoding 3
	entry.pos = math.max(0, math.min(ie.x - 3 + entry.scroll, #entry.value))
	return true
end

local function clearLine(entry)
	local input = tostring(entry.value)
	if #input > 0 then
		entry:reset()
		return true
	end
end

local mappings = {
	[ 'left' ]             = moveLeft,
	[ 'control-b' ]        = moveLeft,
	[ 'right' ]            = moveRight,
	[ 'control-f' ]        = moveRight,
	[ 'home' ]             = moveStart,
	[ 'control-a' ]        = moveStart,
	[ 'end' ]              = moveEnd,
	[ 'control-e' ]        = moveEnd,
	[ 'backspace' ]        = backspace,
	[ 'control-right' ]    = moveWordRight,
	[ 'alt-f' ]            = moveWordRight,
	[ 'control-left' ]     = moveWordLeft,
	[ 'alt-b' ]            = moveWordLeft,
	[ 'delete' ]           = delete,
	[ 'control-u' ]        = cutFromStart,
	[ 'control-k' ]        = cutToEnd,
	[ 'control-d' ]        = cutNextWord,
	[ 'control-w' ]        = cutPrevWord,
	[ 'char' ]             = insertChar,
	[ 'copy' ]             = copy,
	[ 'paste' ]            = paste,
	[ 'control-y' ]        = paste,
	[ 'mouse_click' ]      = moveCursor,
	[ 'mouse_rightclick' ] = clearLine,
}

function Entry:process(ie)
	local action = mappings[ie.code]
	local updated

	if action then
		updated = action(self, ie)
	end

	self:updateScroll()

	return updated
end

return Entry

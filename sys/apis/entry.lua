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

function Entry:updateScroll()
	if self.pos - self.scroll > self.width then
		self.scroll = self.pos - (self.width)
	elseif self.pos < self.scroll then
		self.scroll = self.pos
	end
end

function Entry:process(ie)
	local updated = false

	if ie.code == 'left' then
		if self.pos > 0 then
			self.pos = math.max(self.pos - 1, 0)
			updated = true
		end

	elseif ie.code == 'right' then
		local input = tostring(self.value)
		if self.pos < #input then
			self.pos = math.min(self.pos + 1, #input)
			updated = true
		end

	elseif ie.code == 'home' then
		if self.pos ~= 0 then
			self.pos = 0
			updated = true
		end

	elseif ie.code == 'end' then
		if self.pos ~= #tostring(self.value) then
			self.pos = #tostring(self.value)
			updated = true
		end

	elseif ie.code == 'backspace' then
		if self.pos > 0 then
			local input = tostring(self.value)
			self.value = input:sub(1, self.pos - 1) .. input:sub(self.pos + 1)
			self.pos = self.pos - 1
			updated = true
		end

	elseif ie.code == 'control-right' then
		local nx = nextWord(self.value, self.pos + 1)
		if nx then
			self.pos = math.min(nx - 1, #self.value)
		elseif self.pos < #self.value then
			self.pos = #self.value
		end
		updated = true

	elseif ie.code == 'control-left' then
		if self.pos ~= 0 then
			local lx = 1
			while true do
				local nx = nextWord(self.value, lx)
				if not nx or nx >= self.pos then
					break
				end
				lx = nx
			end
			if not lx then
				self.pos = 0
			else
				self.pos = lx - 1
			end
			updated = true
		end

	elseif ie.code == 'delete' then
		local input = tostring(self.value)
		if self.pos < #input then
			self.value = input:sub(1, self.pos) .. input:sub(self.pos + 2)
			self.update = true
			updated = true
		end

	elseif ie.code == 'char' then
		local input = tostring(self.value)
		if #input < self.limit then
			self.value = input:sub(1, self.pos) .. ie.ch .. input:sub(self.pos + 1)
			self.pos = self.pos + 1
			self.update = true
			updated = true
		end

	elseif ie.code == 'copy' then
		os.queueEvent('clipboard_copy', self.value)

	elseif ie.code == 'paste' then
		local input = tostring(self.value)
		if #input + #ie.text > self.limit then
			ie.text = ie.text:sub(1, self.limit-#input)
		end
		self.value = input:sub(1, self.pos) .. ie.text .. input:sub(self.pos + 1)
		self.pos = self.pos + #ie.text
		updated = true

	elseif ie.code == 'mouse_click' then
		-- need starting x passed in instead of hardcoding 3
		self.pos = math.min(ie.x - 3 + self.scroll, #self.value)
		updated = true

	elseif ie.code == 'mouse_rightclick' then
		local input = tostring(self.value)
		if #input > 0 then
			self:reset()
			updated = true
		end
	end

	self:updateScroll()

	return updated
end

return Entry

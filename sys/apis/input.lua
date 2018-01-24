local Util = require('util')

local keyboard = _G.device and _G.device.keyboard
local keys     = _G.keys
local os       = _G.os

local modifiers = Util.transpose {
	keys.leftCtrl,  keys.rightCtrl,
	keys.leftShift, keys.rightShift,
	keys.leftAlt,   keys.rightAlt,
}

local input = {
	state = { },
}

if not keyboard then
	keyboard = { state = input.state }
end

function input:modifierPressed()
	return keyboard.state[keys.leftCtrl] or
				 keyboard.state[keys.rightCtrl] or
				 keyboard.state[keys.leftAlt] or
				 keyboard.state[keys.rightAlt]
end

function input:toCode(ch, code)
	local result = { }

	if not ch and code == 1 then
		ch = 'escape'
	end

	if keyboard.state[keys.leftCtrl] or keyboard.state[keys.rightCtrl] or
		 code == keys.leftCtrl or code == keys.rightCtrl then
		table.insert(result, 'control')
	end

	-- the key-up event for alt keys is not generated if the minecraft
	-- window loses focus
	--
	-- if keyboard.state[keys.leftAlt] or keyboard.state[keys.rightAlt] or
	--    code == keys.leftAlt or code == keys.rightAlt then
	--   table.insert(result, 'alt')
	-- end

	if keyboard.state[keys.leftShift] or keyboard.state[keys.rightShift] or
		 code == keys.leftShift or code == keys.rightShift then
		if code and modifiers[code] then
			table.insert(result, 'shift')
		elseif #ch == 1 then
			table.insert(result, ch:upper())
		else
			table.insert(result, 'shift')
			table.insert(result, ch)
		end
	elseif not code or not modifiers[code] then
		table.insert(result, ch)
	end

	return table.concat(result, '-')
end

function input:reset()
	self.state = { }
	self.fired = nil

	self.timer = nil
	self.mch = nil
	self.mfired = nil
end

function input:translate(event, code, p1, p2)
	if event == 'key' then
		if p1 then -- key is held down
			if not modifiers[code] then
				self.fired = true
				return { code = input:toCode(keys.getName(code), code) }
			end
		else
			self.state[code] = true
			if self:modifierPressed() and not modifiers[code] or code == 57 then
				self.fired = true
				return { code = input:toCode(keys.getName(code), code) }
			else
				self.fired = false
			end
		end

	elseif event == 'char' then
		if not self:modifierPressed() then
			self.fired = true
			return { code = event, ch = input:toCode(code) }
		end

	elseif event == 'key_up' then
		if not self.fired then
			if self.state[code] then
				self.fired = true
				local ch = input:toCode(keys.getName(code), code)
				self.state[code] = nil
				return { code = ch }
			end
		end
		self.state[code] = nil

	elseif event == 'paste' then
		self.fired = true
		if keyboard.state[keys.leftShift] or keyboard.state[keys.rightShift] then
			return { code = 'shift-paste', text = code }
		else
			return { code = 'paste', text = code }
		end

	elseif event == 'mouse_click' then
		local buttons = { 'mouse_click', 'mouse_rightclick' }
		self.mch = buttons[code]
		self.mfired = nil

	elseif event == 'mouse_drag' then
		self.mfired = true
		self.fired = true
		return {
			code = input:toCode('mouse_drag', 255),
			button = code,
			x = p1,
			y = p2,
		}

	elseif event == 'mouse_up' then
		if not self.mfired then
			local clock = os.clock()
			if self.timer and
				 p1 == self.x and p2 == self.y and
				 (clock - self.timer < .5) then

				self.mch = 'mouse_doubleclick'
				self.timer = nil
			else
				self.timer = os.clock()
				self.x = p1
				self.y = p2
			end
			self.mfired = input:toCode(self.mch, 255)
		else
			self.mch = 'mouse_up'
			self.mfired = input:toCode(self.mch, 255)
		end
		self.fired = true
		return {
			code = self.mfired,
			button = code,
			x = p1,
			y = p2,
		}

	elseif event == "mouse_scroll" then
		local directions = {
			[ -1 ] = 'scroll_up',
			[  1 ] = 'scroll_down'
		}
		self.fired = true
		return {
			code = input:toCode(directions[code], 255),
			x = p1,
			y = p2,
		}

	elseif event == 'terminate' then
		return { code = 'terminate' }
	end
end

function input:test()
	while true do
		local ch = self:translate(os.pullEvent())
		if ch then
			Util.print(ch)
		end
	end
end

return input
local Peripheral = require('opus.peripheral')

_G.device = Peripheral.getList()

_G.device.terminal = _G.kernel.terminal
_G.device.terminal.side = 'terminal'
_G.device.terminal.type = 'terminal'
_G.device.terminal.name = 'terminal'

_G.device.keyboard = {
	side    = 'keyboard',
	type    = 'keyboard',
	name    = 'keyboard',
	hotkeys = { },
	state   = { },
}

_G.device.mouse = {
	side    = 'mouse',
	type    = 'mouse',
	name    = 'mouse',
	state   = { },
}

local Input      = require('opus.input')
local Util       = require('opus.util')

local device   = _G.device
local kernel   = _G.kernel
local keyboard = _G.device.keyboard
local keys     = _G.keys
local mouse    = _G.device.mouse
local os       = _G.os

kernel.hook('peripheral', function(_, eventData)
	local side = eventData[1]
	if side then
		local dev = Peripheral.addDevice(device, side)
		if dev then
			os.queueEvent('device_attach', dev.name)
		end
	end
end)

kernel.hook('peripheral_detach', function(_, eventData)
	local side = eventData[1]
	if side then
		for _, dev in pairs(Util.findAll(device, 'side', side)) do
			os.queueEvent('device_detach', dev.name)
			device[dev.name] = nil
		end
	end
end)

local modifiers = Util.transpose {
	keys.leftCtrl,  keys.rightCtrl,
	keys.leftShift, keys.rightShift,
	keys.leftAlt,   keys.rightAlt,
}

kernel.hook({ 'key', 'char', 'paste' }, function(event, eventData)
	local code = eventData[1]

	-- maintain global keyboard modifier state
	if event == 'key' and modifiers[code] then
		keyboard.state[code] = true
	end

	-- and fire hotkeys
	local hotkey = Input:translate(event, eventData[1], eventData[2])

	if hotkey and keyboard.hotkeys[hotkey.code] then
		keyboard.hotkeys[hotkey.code](event, eventData)
		return true
	end
end)

kernel.hook('key_up', function(_, eventData)
	local code = eventData[1]

	if modifiers[code] then
		keyboard.state[code] = nil
	end
end)

kernel.hook({ 'mouse_click', 'mouse_up', 'mouse_drag' }, function(event, eventData)
	local button = eventData[1]
	if event == 'mouse_click' then
		mouse.state[button] = true
	else
		if not mouse.state[button] then
			return true -- ensure mouse ups are only generated if a mouse down was sent
		end
		if event == 'mouse_up' then
			mouse.state[button] = nil
		end
	end
end)

function keyboard.addHotkey(code, fn)
	keyboard.hotkeys[code] = fn
end

function keyboard.removeHotkey(code)
	keyboard.hotkeys[code] = nil
end

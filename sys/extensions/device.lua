_G.requireInjector()

local Peripheral = require('peripheral')

_G.device = Peripheral.getList()

_G.device.terminal = _G.term.current()
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

local Input      = require('input')
local Util       = require('util')

local device   = _G.device
local kernel   = _G.kernel
local keyboard = _G.device.keyboard
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
    local dev = Util.find(device, 'side', side)
    if dev then
      os.queueEvent('device_detach', dev.name)
      device[dev.name] = nil
    end
  end
end)

kernel.hook({ 'key', 'key_up', 'char', 'paste' }, function(event, eventData)
	local code = eventData[1]

	-- maintain global keyboard state
	if event == 'key' then
		keyboard.state[code] = true
	elseif event == 'key_up' then
		if not keyboard.state[code] then
			return true -- ensure key ups are only generated if a key down was sent
		end
		keyboard.state[code] = nil
	end

	-- and fire hotkeys
  local hotkey = Input:translate(event, eventData[1], eventData[2])

  if hotkey and keyboard.hotkeys[hotkey] then
    keyboard.hotkeys[hotkey](event, eventData)
  end
end)

function keyboard.addHotkey(code, fn)
  keyboard.hotkeys[code] = fn
end

function keyboard.removeHotkey(code)
  keyboard.hotkeys[code] = nil
end

kernel.hook('monitor_touch', function(event, eventData)
	local monitor = Peripheral.getBySide(eventData[1])
	if monitor and monitor.eventChannel then
		monitor.eventChannel(event, table.unpack(eventData))
		return true -- stop propagation
	end
end)

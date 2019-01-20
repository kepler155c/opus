local os         = _G.os
local parallel   = _G.parallel
local peripheral = _G.peripheral
local settings   = _G.settings
local term       = _G.term

local name = settings.get('kiosk.monitor')

if not name then
	peripheral.find('monitor', function(s)
		name = s
	end)
end

local mon = name and peripheral.wrap(name)

if mon then
	term.redirect(mon)
	mon.setTextScale(tonumber(settings.get('kiosk.textscale')) or 1)

	parallel.waitForAny(
		function()
			os.run(_ENV, '/sys/boot/opus.boot')
		end,

		function()
			while true do
				local event, side, x, y = os.pullEventRaw('monitor_touch')

				if event == 'monitor_touch' and side == name then
					os.queueEvent('mouse_click', 1, x, y)
					os.queueEvent('mouse_up',    1, x, y)
				end
			end
		end
	)
else
	os.run(_ENV, '/sys/boot/opus.boot')
end

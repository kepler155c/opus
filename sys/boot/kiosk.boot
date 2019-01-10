local os         = _G.os
local parallel   = _G.parallel
local peripheral = _G.peripheral
local settings   = _G.settings
local term       = _G.term

local mon = peripheral.find('monitor')
if mon then
	term.redirect(mon)
	if not settings.get('kiosk.textscale') then
		settings.set('kiosk.textscale', .5)
	end
	mon.setTextScale(settings.get('kiosk.textscale') or .5)

	parallel.waitForAny(
		function()
			os.run(_ENV, '/sys/boot/opus.boot')
		end,

		function()
			while true do
				local event, _, x, y = os.pullEventRaw('monitor_touch')

				if event == 'monitor_touch' then
					os.queueEvent('mouse_click', 1, x, y)
					os.queueEvent('mouse_up',    1, x, y)
				end
			end
		end
	)
else
	os.run(_ENV, '/sys/boot/opus.boot')
end

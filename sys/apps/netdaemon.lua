local Event = require('opus.event')
local Util  = require('opus.util')

local device     = _G.device
local fs         = _G.fs
local network    = _G.network
local os         = _G.os
local printError = _G.printError

if not device.wireless_modem then
	return
end

print('Net daemon starting')
-- don't close as multiple computers may be sharing the
-- wireless modem
--device.wireless_modem.closeAll()

for _,file in pairs(fs.list('sys/apps/network')) do
	local fn, msg = Util.run(_ENV, 'sys/apps/network/' .. file)
	if not fn then
		printError(msg)
	end
end

Event.on('device_detach', function()
	if not device.wireless_modem then
		Event.exitPullEvents()
	end
end)

print('Net daemon started')
os.queueEvent('network_up')
Event.pullEvents()

for _,c in pairs(network) do
	c.active = false
	os.queueEvent('network_detach', c)
end
os.queueEvent('network_down')
Event.pullEvent('network_down')

Util.clear(network)

print('Net daemon stopped')

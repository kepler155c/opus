_G.requireInjector(_ENV)

local Event = require('event')
local Util  = require('util')

local device     = _G.device
local fs         = _G.fs
local network    = _G.network
local os         = _G.os
local printError = _G.printError

if not device.wireless_modem then
	return
end

print('Net daemon starting')

for _,file in pairs(fs.list('sys/network')) do
	local fn, msg = Util.run(_ENV, 'sys/network/' .. file)
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

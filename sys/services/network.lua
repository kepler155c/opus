_G.requireInjector()

local Util = require('util')

local device     = _G.device
local fs         = _G.fs
local multishell = _ENV.multishell
local os         = _G.os
local printError = _G.printError

local network = { }
_G.network = network

multishell.setTitle(multishell.getCurrent(), 'Net Daemon')

local function netUp()
  _G.requireInjector()

  local Event = require('event')
_G._e2 = _ENV
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

  Event.pullEvents()

  for _,c in pairs(network) do
    c.active = false
    os.queueEvent('network_detach', c)
  end
  os.queueEvent('network_down')
  Event.pullEvent('network_down')

  Util.clear(_G.network)
end

print('Net daemon started')

local function startNetwork()
  print('Starting network services')

_G._e1 = _ENV

  local success, msg = Util.runFunction(
    Util.shallowCopy(_ENV), netUp)

  if not success and msg then
    printError(msg)
  end
  print('Network services stopped')
end

if device.wireless_modem then
  startNetwork()
else
  print('No modem detected')
end

while true do
  local _, deviceName = os.pullEvent('device_attach')
  if deviceName == 'wireless_modem' then
    startNetwork()
  end
end

print('Net daemon stopped')

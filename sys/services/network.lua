requireInjector(getfenv(1))

local Util = require('util')

multishell.setTitle(multishell.getCurrent(), 'Net Daemon')

_G.network = { }

local function netUp()
  requireInjector(getfenv(1))
  local Event = require('event')

  local files = fs.list('/sys/network')

  for _,file in pairs(files) do
    local fn, msg = loadfile('/sys/network/' .. file, getfenv(1))
    if fn then
      fn()
    else
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

  local success, msg = Util.runFunction(
    Util.shallowCopy(getfenv(1)), netUp)

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
  local e, deviceName = os.pullEvent('device_attach')
  if deviceName == 'wireless_modem' then
    startNetwork()
  end
end

print('Net daemon stopped')

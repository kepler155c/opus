require = requireInjector(getfenv(1))
local Event = require('event')
local Peripheral = require('peripheral')

multishell.setTitle(multishell.getCurrent(), 'Devices')

local attachColor = colors.green
local detachColor = colors.red

if not term.isColor() then
  attachColor = colors.white
  detachColor = colors.lightGray
end

Event.on('peripheral', function(event, side)
  if side then
    local dev = Peripheral.addDevice(device, side)
    if dev then
      term.setTextColor(attachColor)
      Util.print('[%s] %s attached', dev.side, dev.name)
      os.queueEvent('device_attach', dev.name)
    end
  end
end)

Event.on('peripheral_detach', function(event, side)
  if side then
    local dev = Util.find(device, 'side', side)
    if dev then
      term.setTextColor(detachColor)
      Util.print('[%s] %s detached', dev.side, dev.name)
      os.queueEvent('device_detach', dev.name)
      device[dev.name] = nil
    end
  end
end)

print('waiting for peripheral changes')
Event.pullEvents()

if _G.device then
  return
end

requireInjector(getfenv(1))

local Peripheral = require('peripheral')

_G.device = { }

for _,side in pairs(peripheral.getNames()) do
  Peripheral.addDevice(device, side)
end

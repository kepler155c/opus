_G.device = { }

require = requireInjector(getfenv(1))
local Peripheral = require('peripheral')

for _,side in pairs(peripheral.getNames()) do
  Peripheral.addDevice(side)
end

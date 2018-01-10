_G.requireInjector()

local Util = require('util')

local kernel    = _G.kernel
local keyboard  = _G.device.keyboard
local textutils = _G.textutils

local data

kernel.hook('clipboard_copy', function(_, args)
  data = args[1]
end)

keyboard.addHotkey('shift-paste', function(_, args)
  if type(data) == 'table' then
    local s, m = pcall(textutils.serialize, data)
    data = (s and m) or Util.tostring(data)
  end
  -- replace the event paste data with our internal data
  args[1] = Util.tostring(data or '')
end)

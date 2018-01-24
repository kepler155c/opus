_G.requireInjector(_ENV)

local Util = require('util')

local kernel    = _G.kernel
local keyboard  = _G.device.keyboard
local os        = _G.os
local textutils = _G.textutils

local data

kernel.hook('clipboard_copy', function(_, args)
	data = args[1]
end)

keyboard.addHotkey('shift-paste', function()
	if type(data) == 'table' then
		local s, m = pcall(textutils.serialize, data)
		data = (s and m) or Util.tostring(data)
	end
	-- replace the event paste data with our internal data
	-- args[1] = Util.tostring(data or '')
	if data then
		os.queueEvent('paste', data)
	end
end)

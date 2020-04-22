local Util = require('opus.util')

local kernel    = _G.kernel
local keyboard  = _G.device.keyboard
local os        = _G.os
local textutils = _G.textutils

kernel.hook('clipboard_copy', function(_, args)
	keyboard.clipboard =  args[1]
end)

local function queuePaste()
	local data = keyboard.clipboard

	if type(data) == 'table' then
		local s, m = pcall(textutils.serialize, data)
		data = s and m or Util.tostring(data)
	end

	if data then
		os.queueEvent('paste', data)
	end
end

kernel.hook('clipboard_paste', queuePaste)
keyboard.addHotkey('shift-paste', queuePaste)

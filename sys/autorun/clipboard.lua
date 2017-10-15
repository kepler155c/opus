_G.requireInjector()

local Util = require('util')

local keys       = _G.keys
local multishell = _ENV.multishell
local textutils  = _G.textutils

local clipboard = { }

function clipboard.getText()
  if clipboard.data then
    if type(clipboard.data) == 'table' then
      local s, m = pcall(textutils.serialize, clipboard.data)
      clipboard.data = (s and m) or Util.tostring(clipboard.data)
    end
    return Util.tostring(clipboard.data)
  end
end

function clipboard.useInternal(mode)
  if mode ~= clipboard.internal then
    clipboard.internal = mode
    local text = 'Clipboard (^m): ' .. ((mode and 'internal') or 'normal')
    multishell.showMessage(text)
  end
end

multishell.hook('clipboard_copy', function(_, args)
  clipboard.data = args[1]
  if clipboard.data then
    clipboard.useInternal(true)
  end
end)

multishell.hook('paste', function(_, args)
  if clipboard.internal then
    args[1] = clipboard.getText() or ''
  end
end)

-- control-m - toggle clipboard mode
multishell.addHotkey(keys.m, function()
  clipboard.useInternal(not clipboard.internal)
end)

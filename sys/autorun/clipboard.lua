_G.requireInjector()

local Util = require('util')

local multishell = _ENV.multishell
local os         = _G.os

local clipboard = { }

function clipboard.getData()
  return clipboard.data
end

function clipboard.setData(data)
  clipboard.data = data
  if data then
    clipboard.useInternal(true)
  end
end

function clipboard.getText()
  if clipboard.data then
    return Util.tostring(clipboard.data)
  end
end

function clipboard.isInternal()
  return clipboard.internal
end

function clipboard.useInternal(mode)
  if mode ~= clipboard.internal then
    clipboard.internal = mode
    local text = 'Clipboard (^m): ' .. ((mode and 'internal') or 'normal')
    multishell.showMessage(text)
    os.queueEvent('clipboard_mode', mode)
  end
end

multishell.hook('clipboard_copy', function(_, args)
  clipboard.setData(args[1])
end)

multishell.hook('paste', function(_, args)
  if clipboard.isInternal() then
    args[1] = clipboard.getText() or ''
  end
end)

-- control-m - clipboard mode
multishell.addHotkey(50, function()
  clipboard.useInternal(not clipboard.isInternal())
end)

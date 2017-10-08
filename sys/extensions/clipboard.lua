if _G.clipboard then
  return
end

_G.requireInjector()
local Util = require('util')
local os   = _G.os

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
    os.queueEvent('clipboard_mode', mode)
  end
end

_G.clipboard = clipboard

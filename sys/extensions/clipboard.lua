_G.clipboard = { internal, data }

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
  if mode ~= clipboard.mode then
    clipboard.internal = mode
    os.queueEvent('clipboard_mode', mode)
  end
end

multishell.addHotkey(20, function()
  clipboard.useInternal(not clipboard.isInternal())
end)

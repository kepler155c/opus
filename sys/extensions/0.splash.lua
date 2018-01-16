if false then
  local colors = _G.colors
  local term   = _G.term
  local window = _G.window

  local terminal = term.current()
  local w, h = term.getSize()

  local splashWindow = window.create(terminal.parent, 1, 1, w, h, false)
  splashWindow.setTextColor(colors.white)
  if splashWindow.isColor() then
    splashWindow.setBackgroundColor(colors.black)
    splashWindow.clear()
    local opus = {
      'fffff00',
      'ffff07000',
      'ff00770b00 4444',
      'ff077777444444444',
      'f07777744444444444',
      'f0000777444444444',
      '070000111744444',
      '777770000',
      '7777000000',
      '70700000000',
      '077000000000',
    }
    for k,line in ipairs(opus) do
      splashWindow.setCursorPos((w - 18) / 2, k + (h - #opus) / 2)
      splashWindow.blit(string.rep(' ', #line), string.rep('a', #line), line)
    end
  end

  local str = 'Loading Opus OS...'
  print(str)
  splashWindow.setCursorPos((w - #str) / 2, h)
  splashWindow.write(str)

  terminal.setVisible(false)
  splashWindow.setVisible(true)

  kernel.hook('kernel_ready', function()
    kernel.window.setVisible(true)
  end)
end

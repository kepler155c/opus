_G.requireInjector()

--[[
  Adds the control-d hotkey to view the kernel log.
]]

local Terminal = require('terminal')

local kernel     = _G.kernel
local keyboard   = _G.device.keyboard
local multishell = _ENV.multishell
local os         = _G.os
local term       = _G.term
local window     = _G.window

if multishell and multishell.setTitle then
  multishell.setTitle(multishell.getCurrent(), 'System Log')
end

-- jump through a lot of hoops to get around window api limitations
-- mainly failing to provide access to window buffer or knowledge of parent
-- need: window.getParent()
--       window.copy(target)

local terminal = _G.kernel.terminal.parent
local w, h = kernel.window.getSize()
local win = window.create(kernel.window, 1, 1, w, h + 50, false)

-- copy windows contents from parent window to child
local oblit, oscp = terminal.blit, terminal.setCursorPos
kernel.window.setVisible(false)
terminal.blit = function(...)
  win.blit(...)
end
terminal.setCursorPos = function(...)
  win.setCursorPos(...)
end
kernel.window.setVisible(true)

-- position and resize window for multishell (but don't update screen)
terminal.blit = function() end
terminal.setCursorPos = function() end
kernel.window.reposition(1, 2, w, h - 1)

-- restore original terminal
terminal.blit = oblit
terminal.setCursorPos = oscp

-- add scrolling methods
Terminal.scrollable(win, kernel.window)

-- update kernel with new window, set this tab with the new kernal window
local routine = kernel.getCurrent()
for _,r in pairs(kernel.routines) do
  if r.terminal == kernel.terminal then
    r.terminal = win
    r.window = win
  end
end
kernel.terminal = win
kernel.window = win
routine.terminal = win
routine.window = win
term.redirect(routine.window)

local previousId

kernel.hook('mouse_scroll', function(_, eventData)
  local dir, y = eventData[1], eventData[3]

  if y > 1 then
    local currentTab = kernel.routines[1]
    if currentTab.terminal.scrollUp then
      if dir == -1 then
        currentTab.terminal.scrollUp()
      else
        currentTab.terminal.scrollDown()
      end
    end
  end
end)

keyboard.addHotkey('control-d', function()
  local current = kernel.getFocused()
  if current.uid ~= routine.uid then
    previousId = current.uid
    kernel.raise(routine.uid)
  elseif previousId then
    kernel.raise(previousId)
  end
end)

os.pullEventRaw('terminate')
keyboard.removeHotkey('control-d')

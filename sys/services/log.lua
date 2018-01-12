_G.requireInjector()

local Terminal = require('terminal')
local Util     = require('util')

local kernel     = _G.kernel
local keyboard   = _G.device.keyboard
local multishell = _ENV.multishell
local os         = _G.os
local term       = _G.term

_ENV._APP_TITLE = 'Debug'

term.redirect(Terminal.scrollable(term.current(), 50))

local tabId = multishell.getCurrent()
local previousId

_G.debug = function(pattern, ...)
  local oldTerm = term.current()
  term.redirect(kernel.terminal)
  Util.print(pattern, ...)
  term.redirect(oldTerm)
end

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

print('Debug started')
print('Press ^d to activate debug window')

keyboard.addHotkey('control-d', function()
  local currentId = multishell.getFocus()
  if currentId ~= tabId then
    previousId = currentId
    multishell.setFocus(tabId)
  elseif previousId then
    multishell.setFocus(previousId)
  end
end)

os.pullEventRaw('terminate')

print('Debug stopped')

_G.debug = function() end
keyboard.removeHotkey('control-d')

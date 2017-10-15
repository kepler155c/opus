_G.requireInjector()

local Terminal = require('terminal')
local Util     = require('util')

local keys       = _G.keys
local multishell = _ENV.multishell
local os         = _G.os
local term       = _G.term

multishell.setTitle(multishell.getCurrent(), 'Debug')

term.redirect(Terminal.scrollable(term.current(), 50))

local tabId = multishell.getCurrent()
local terminal = term.current()
local previousId

_G.debug = function(pattern, ...)
  local oldTerm = term.current()
  term.redirect(terminal)
  Util.print(pattern, ...)
  term.redirect(oldTerm)
end

print('Debug started')
print('Press ^d to activate debug window')

multishell.addHotkey(keys.d, function()
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
multishell.removeHotkey(keys.d)

require = requireInjector(getfenv(1))
local Terminal = require('terminal')

multishell.setTitle(multishell.getCurrent(), 'Debug')

term.redirect(Terminal.scrollable(term.current(), 50))

local tabId = multishell.getCurrent()
local tab = multishell.getTab(tabId)
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

multishell.addHotkey(32, function()
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
multishell.removeHotkey(32)

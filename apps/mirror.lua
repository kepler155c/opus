require = requireInjector(getfenv(1))
local Terminal = require('terminal')
local process = require('process')

local args = { ... }
local mon = device[table.remove(args, 1) or 'monitor']
if not mon then
  error('mirror: Invalid device')
end

mon.clear()
mon.setTextScale(.5)
mon.setCursorPos(1, 1)

local oterm = Terminal.copy(term.current())
Terminal.mirror(term.current(), mon)

term.current().getSize = function() return mon.getSize() end

if #args > 0 then
  shell.run(unpack(args))
  Terminal.copy(oterm, term.current())

  mon.setCursorBlink(false)
end

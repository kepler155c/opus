local pullEvent = os.pullEventRaw
local redirect = term.redirect
local current = term.current
local shutdown = os.shutdown

local cos = { }

os.pullEventRaw = function(...)
  local co = coroutine.running()
  if not cos[co] then
    cos[co] = true
    error('die')
  end
  return pullEvent(...)
end

os.shutdown = function()
end

term.current = function()
  term.redirect = function()
    os.pullEventRaw = pullEvent
    os.shutdown = shutdown
    term.current = current
    term.redirect = redirect

    term.redirect(term.native())
    --for co in pairs(cos) do
    --  print(tostring(co) .. ' ' .. coroutine.status(co))
    --end
    os.run(getfenv(1), 'sys/boot/multishell.boot')
    os.run(getfenv(1), 'rom/programs/shell')
  end
  error('die')
end

os.queueEvent('modem_message')

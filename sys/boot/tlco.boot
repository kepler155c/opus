local pullEvent = os.pullEventRaw
local shutdown = os.shutdown

os.pullEventRaw = function()
  error('die')
end

os.shutdown = function()
  os.pullEventRaw = pullEvent
  os.shutdown = shutdown

  os.run(getfenv(1), 'sys/boot/multishell.boot')
end

os.queueEvent('modem_message')

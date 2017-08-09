require = requireInjector(getfenv(1))
local Event = require('event')
local Socket = require('socket')
local Terminal = require('terminal')

local remoteId
local args = { ... }
if #args == 1 then
  remoteId = tonumber(args[1])
else
  print('Enter host ID')
  remoteId = tonumber(read())
end

if not remoteId then
  error('Syntax: telnet <host ID>')
end

print('connecting...')
local socket = Socket.connect(remoteId, 23)

if not socket then
  error('Unable to connect to ' .. remoteId .. ' on port 23')
end

local ct = Util.shallowCopy(term.current())
if not ct.isColor() then
  Terminal.toGrayscale(ct)
end

local w, h = ct.getSize()
socket:write({
  width = w,
  height = h,
  isColor = ct.isColor(),
})

Event.addRoutine(function()
  while true do
    local data = socket:read()
    if not data then
      break
    end
    for _,v in ipairs(data) do
      ct[v.f](unpack(v.args))
    end
  end
end)

ct.clear()
ct.setCursorPos(1, 1)

local filter = Util.transpose({
  'char', 'paste', 'key', 'key_up', 'terminate',
  'mouse_scroll', 'mouse_click', 'mouse_drag', 'mouse_up',
})

while true do
  local e = { os.pullEventRaw() }
  local event = e[1]

  if filter[event] then
    socket:write(e)
  else
    Event.processEvent(e)
  end

  if not socket.connected then
    print()
    print('Connection lost')
    print('Press enter to exit')
    read()
    break
  end
end

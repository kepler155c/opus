_G.requireInjector()

local Event    = require('event')
local Socket   = require('socket')
local Terminal = require('terminal')
local Util     = require('util')

local colors     = _G.colors
local multishell = _ENV.multishell
local term       = _G.term

local remoteId
local args = { ... }
if #args == 1 then
  remoteId = tonumber(args[1])
else
  print('Enter host ID')
  remoteId = tonumber(_G.read())
end

if not remoteId then
  error('Syntax: vnc <host ID>')
end

multishell.setTitle(multishell.getCurrent(), 'VNC-' .. remoteId)

print('connecting...')
local socket, msg = Socket.connect(remoteId, 5900)

if not socket then
  error(msg)
end

local function writeTermInfo()
  local w, h = term.getSize()
  socket:write({
    type = 'termInfo',
    width = w,
    height = h,
    isColor = term.isColor(),
  })
end

writeTermInfo()

local ct = Util.shallowCopy(term.current())

if not ct.isColor() then
  Terminal.toGrayscale(ct)
end

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
  'char', 'paste', 'key', 'key_up',
  'mouse_scroll', 'mouse_click', 'mouse_drag', 'mouse_up',
})

while true do
  local e = Event.pullEvent()
  local event = e[1]

  if not socket.connected then
    print()
    print('Connection lost')
    print('Press enter to exit')
    _G.read()
    break
  end

  if filter[event] then
    socket:write({
      type = 'shellRemote',
      event = e,
    })
  elseif event == 'term_resize' then
    writeTermInfo()
  elseif event == 'terminate' then
    socket:close()
    ct.setBackgroundColor(colors.black)
    ct.clear()
    ct.setCursorPos(1, 1)
    break
  end
end

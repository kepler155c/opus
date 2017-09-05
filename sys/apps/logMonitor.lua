requireInjector(getfenv(1))

local Event   = require('event')
local Message = require('message')
local UI      = require('ui')
local Util    = require('util')

multishell.setTitle(multishell.getCurrent(), 'Log Monitor')

if not device.wireless_modem then
  error('Wireless modem is required')
end
device.wireless_modem.open(59998)

local ids = { }
local messages = { }
local terminal = UI.term

if device.openperipheral_bridge then

  UI.Glasses = require('glasses')

  terminal = UI.Glasses({
    x = 4,
    y = 175,
    height = 40,
    width = 64,
    textScale = .5,
    backgroundOpacity = .65,

  })
elseif device.monitor then
  terminal = UI.Device({
    deviceType = 'monitor',
    textScale = .5
  })
end

terminal:clear()

function getClient(id)
  if not ids[id] then
    ids[id] = {
      titleBar      = UI.TitleBar({ title = 'ID: ' .. id, parent = terminal }),
      scrollingText = UI.ScrollingText({ parent = terminal })
    }
    local clientCount = Util.size(ids)
    local clientHeight = math.floor((terminal.height - clientCount) / clientCount)
    terminal:clear()
    local y = 1
    for k,v in pairs(ids) do
      v.titleBar.y = y
      y = y + 1
      v.scrollingText.height = clientHeight
      v.scrollingText.y = y
      y = y + clientHeight
      v.scrollingText:clear()

      v.titleBar:draw()
      v.scrollingText:draw()
    end
  end
  return ids[id]
end

Event.on('logMessage', function()
  local t = { }
  while #messages > 0 do
    local msg = messages[1]
    table.remove(messages, 1)
    local client = getClient(msg.id)
    client.scrollingText:appendLine(string.format('%d %s', math.floor(os.clock()),  msg.text))
    t[msg.id] = client
  end
  for _,client in pairs(t) do
    client.scrollingText:draw()
  end
  terminal:sync()
end)

Message.addHandler('log', function(h, id, msg)
  table.insert(messages, { id = id, text = msg.contents })
  os.queueEvent('logMessage')
end)

Event.on('monitor_touch', function()
  terminal:reset()
  ids = { }
end)

Event.on('mouse_click', function()
  terminal:reset()
  ids = { }
end)

Event.on('char', function()
  Event.exitPullEvents()
end)

Event.pullEvents(logWriter)
terminal:reset()

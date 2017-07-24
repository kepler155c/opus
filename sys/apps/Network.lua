require = requireInjector(getfenv(1))
local Event = require('event')
local UI = require('ui')
local Socket = require('socket')

multishell.setTitle(multishell.getCurrent(), 'Network')
UI:configure('Network', ...)

local gridColumns = {
  { heading = 'Label',  key = 'label'    },
  { heading = 'Dist',   key = 'distance' },
  { heading = 'Status', key = 'status'   },
}

if UI.term.width >= 30 then
  table.insert(gridColumns, { heading = 'Fuel',   key = 'fuel'   })
  table.insert(gridColumns, { heading = 'Uptime', key = 'uptime' })
end

local page = UI.Page {
  menuBar = UI.MenuBar {
    buttons = {
      { text = 'Telnet', event = 'telnet' },
      { text = 'VNC',    event = 'vnc'    },
      { text = 'Trust',  event = 'trust'  },
      { text = 'Reboot', event = 'reboot' },
    },
  },
  grid = UI.ScrollingGrid {
    y = 2,
    values = network,
    columns = gridColumns,
    sortColumn = 'label',
    autospace = true,
  },
  notification = UI.Notification { },
  accelerators = {
    q = 'quit',
    c = 'clear',
  },
}

local function sendCommand(host, command)

  if not device.wireless_modem then
    page.notification:error('Wireless modem not present')
    return
  end

  page.notification:info('Connecting')
  page:sync()

  local socket = Socket.connect(host, 161)
  if socket then
    socket:write({ type = command })
    socket:close()
    page.notification:success('Command sent')
  else
    page.notification:error('Failed to connect')
  end
end

function page:eventHandler(event)
  local t = self.grid:getSelected()
  if t then
    if event.type == 'telnet' or event.type == 'grid_select' then
      multishell.openTab({
        path = 'sys/apps/telnet.lua',
        focused = true,
        args = { t.id },
        title = t.label,
      })
    elseif event.type == 'vnc' then
      multishell.openTab({
        path = 'sys/apps/vnc.lua',
        focused = true,
        args = { t.id },
        title = t.label,
      })
    elseif event.type == 'trust' then
      shell.openForegroundTab('trust ' .. t.id)
    elseif event.type == 'reboot' then
      sendCommand(t.id, 'reboot')
    elseif event.type == 'shutdown' then
      sendCommand(t.id, 'shutdown')
    end
  end
  if event.type == 'quit' then
    Event.exitPullEvents()
  end
  UI.Page.eventHandler(self, event)
end

function page.grid:getRowTextColor(row, selected)
  if not row.active then
    return colors.orange
  end
  return UI.Grid.getRowTextColor(self, row, selected)
end

function page.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)
  if row.uptime then
    if row.uptime < 60 then
      row.uptime = string.format("%ds", math.floor(row.uptime))
    else
      row.uptime = string.format("%sm", math.floor(row.uptime/6)/10)
    end
  end
  if row.fuel then
    row.fuel = Util.toBytes(row.fuel)
  end
  if row.distance then
    row.distance = Util.round(row.distance, 1)
  end
  return row
end

Event.onInterval(1, function()
  page.grid:update()
  page.grid:draw()
  page:sync()
end)

Event.on('device_attach', function(h, deviceName)
  if deviceName == 'wireless_modem' then
    page.notification:success('Modem connected')
    page:sync()
  end
end)

Event.on('device_detach', function(h, deviceName)
  if deviceName == 'wireless_modem' then
    page.notification:error('Wireless modem not attached')
    page:sync()
  end
end)

if not device.wireless_modem then
  page.notification:error('Wireless modem not attached')
end

UI:setPage(page)
Event.pullEvents()
UI.term:reset()

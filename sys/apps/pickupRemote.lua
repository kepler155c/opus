if not device.wireless_modem then
  error('Wireless modem is required')
end

requireInjector(getfenv(1))

local Event  = require('event')
local GPS    = require('gps')
local Socket = require('socket')
local UI     = require('ui')
local Util   = require('util')

multishell.setTitle(multishell.getCurrent(), 'Pickup Remote')

local id

local mainPage = UI.Page({
  menu = UI.Menu({
    centered = true,
    y = 2,
    menuItems = {
      { prompt = 'Pickup', event = 'pickup', help = 'Pickup items from this location' },
      { prompt = 'Charge cell', event = 'charge', help = 'Recharge this cell' },
      { prompt = 'Refill', event = 'refill', help = 'Recharge this cell' },
      { prompt = 'Set pickup location', event = 'setPickup', help = 'Recharge this cell' },
      { prompt = 'Set recharge location', event = 'setRecharge', help = 'Recharge this cell' },
      { prompt = 'Clear', event = 'clear', help = 'Remove this location' },
    },
  }),
  statusBar = UI.StatusBar(),
  accelerators = {
    q = 'quit',
  },
})

local refillPage = UI.Page({
  menuBar = UI.MenuBar({
    y = 1,
    buttons = {
      { text = 'Done', event = 'done', help = 'Pickup items from this location' },
      { text = 'Back', event = 'back', help = 'Recharge this cell' },
    },
  }),
  grid1 = UI.ScrollingGrid({
    columns = {
      { heading = 'Name', key = 'name', width = UI.term.width-9 },
      { heading = 'Qty',  key = 'fQty', width = 5               },
    },
    sortColumn = 'name',
    height = 8,
    y = 3,
  }),
  grid2 = UI.ScrollingGrid({
    columns = {
      { heading = 'Name', key = 'name', width = UI.term.width-9 },
      { heading = 'Qty',  key = 'qty',  width = 5               },
    },
    sortColumn = 'name',
    height = 4,
    y = 12,
  }),
  statusBar = UI.StatusBar(),
  accelerators = {
    q = 'quit',
  },
})

refillPage.menuBar:add({
  filter = UI.TextEntry({
    x = UI.term.width-10,
    width = 10,
  })
})

local function sendCommand(cmd)
  local socket = Socket.connect(id, 5222)
  if not socket then
    mainPage.statusBar:timedStatus('Unable to connect', 3)
    return
  end

  socket:write(cmd)
  local m = socket:read(3)
  socket:close()
  if m then
    return m.response
  end
  mainPage.statusBar:timedStatus('No response', 3)
end

local function getPoint()
  local gpt = GPS.getPoint()
  if not gpt then
    mainPage.statusBar:timedStatus('Unable to get location', 3)
  end
  return gpt
end

function refillPage:eventHandler(event)

  if event.type == 'grid_select' then

    local item = {
      name = event.selected.name,
      id = event.selected.id,
      dmg = event.selected.dmg,
      qty = 0,
    }

    local dialog = UI.Dialog({
      x = 1,
      width = UI.term.width,
      text = UI.Text({ x = 3, y = 3, value = 'Quantity' }),
      textEntry = UI.TextEntry({ x = 14, y = 3 })
    })
 
    dialog.eventHandler = function(self, event)
      if event.type == 'accept' then
        local l = tonumber(self.textEntry.value)
        if l and l <= 1024 and l > 0 then
          item.qty = self.textEntry.value
          table.insert(refillPage.grid2.values, item)
          refillPage.grid2:update()
          UI:setPreviousPage()
        else
          self.statusBar:timedStatus('Invalid Quantity', 3)
        end
        return true
      end
 
      return UI.Dialog.eventHandler(self, event)
    end
 
    dialog.titleBar.title = item.name
    dialog:setFocus(dialog.textEntry)
    UI:setPage(dialog)

  elseif event.type == 'text_change' then
    local text = event.text
    if #text == 0 then
      self.grid1.values = self.allItems
    else
      self.grid1.values = { }
      for _,item in pairs(self.allItems) do
        if string.find(item.lname, text) then
          table.insert(self.grid1.values, item)
        end
      end
    end
    --self.grid:adjustWidth()
    self.grid1:update()
    self.grid1:setIndex(1)
    self.grid1:draw()

  elseif event.type == 'back' then
    UI:setPreviousPage()

  elseif event.type == 'done' then
    UI:setPage(mainPage)
    local pt = getPoint()
    if pt then
      local response = sendCommand({ type = 'refill', entry = { point = pt, items = self.grid2.values } })
      if response then
        mainPage.statusBar:timedStatus(response, 3)
      end
    end

  elseif event.type == 'grid_focus_row' then
    self.statusBar:setStatus(event.selected.id .. ':' .. event.selected.dmg)
    self.statusBar:draw()
  end

  return UI.Page.eventHandler(self, event)
end

function refillPage:enable()
  for _,item in pairs(self.allItems) do
    item.lname = string.lower(item.name)
    item.fQty = Util.toBytes(item.qty)
  end

  self.grid1:setValues(self.allItems)

  self.menuBar.filter.value = ''
  self.menuBar.filter.pos = 1
  self:setFocus(self.menuBar.filter)
  UI.Page.enable(self)
end

function mainPage:eventHandler(event)

  if event.type == 'quit' then
    Event.exitPullEvents()

  elseif event.type == 'refill' then
    local response = sendCommand({ type = 'items' })
    if response then
      refillPage.allItems = response
      refillPage.grid2:setValues({ })
      UI:setPage(refillPage)
    end

  elseif event.type == 'pickup' or event.type == 'setPickup' or 
         event.type == 'setRecharge' or event.type == 'charge' or
         event.type == 'clear' then
    local pt = getPoint()
    if pt then
      local response = sendCommand({ type = event.type, point = pt })
      if response then
        self.statusBar:timedStatus(response, 3)
      end
    end

  end

  return UI.Page.eventHandler(self, event)
end

local args = { ... }
if #args == 1 then
  id = tonumber(args[1])
end

if not id then
  error('Syntax: pickupRemote <turtle ID>')
end

UI:setPage(mainPage)

Event.pullEvents()
UI.term:reset()

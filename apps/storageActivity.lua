require = requireInjector(getfenv(1))
local Event = require('event')
local UI = require('ui')
local RefinedProvider = require('refinedProvider')
local MEProvider = require('meProvider')

if not device.monitor then
  error('Monitor not found')
end

local storage = RefinedProvider()
if not storage:isValid() then
  storage = MEProvider()
end

if not storage:isValid() then
  error('Not connected to a storage device')
end

local monitor = UI.Device({
  deviceType = 'monitor',
  textScale = .5
})
UI:setDefaultDevice(monitor)

multishell.setTitle(multishell.getCurrent(), 'Storage Activity')
UI:configure('StorageActivity', ...)

-- Strip off color prefix
local function safeString(text)

  local val = text:byte(1)

  if val < 32 or val > 128 then

    local newText = {}
    for i = 4, #text do
      local val = text:byte(i)
      newText[i - 3] = (val > 31 and val < 127) and val or 63
    end
    return string.char(unpack(newText))
  end

  return text
end

local changedPage = UI.Page({
  grid = UI.Grid({
    columns = {
      { heading = 'Qty',    key = 'dispQty', width = 5                  },
      { heading = 'Change', key = 'change',  width = 6                  },
      { heading = 'Name',   key = 'name',    width = monitor.width - 15 },
    },
    sortColumn = 'name',
    height = monitor.height - 6,
  }),
  buttons = UI.Window({
    y = monitor.height - 5,
    height = 5,
    backgroundColor = colors.gray,
    prevButton = UI.Button({
      event = 'previous',
      backgroundColor = colors.lightGray,
      x = 2,
      y = 2,
      height = 3,
      width = 5,
      text = ' < '
    }),
    resetButton = UI.Button({
      event = 'reset',
      backgroundColor = colors.lightGray,
      x = 8,
      y = 2,
      height = 3,
      width = monitor.width - 14,
      text = 'Reset'
    }),
    nextButton = UI.Button({
      event = 'next',
      backgroundColor = colors.lightGray,
      x = monitor.width - 5,
      y = 2,
      height = 3,
      width = 5,
      text = ' > '
    })
  }),
  statusBar = UI.StatusBar({
    columns = {
      { '', 'slots',  18 },
      { '', 'spacer', monitor.width-36 },
      { '', 'space',  15 }
    }
  }),
  accelerators = {
    q = 'quit',
  }
})
 
function changedPage:eventHandler(event)
 
  if event.type == 'reset' then
    self.lastItems = nil
    self.grid:setValues({ })
    self.grid:clear()
    self.grid:draw()

  elseif event.type == 'next' then
    self.grid:nextPage()

  elseif event.type == 'previous' then
    self.grid:previousPage()

  elseif event.type == 'quit' then
    Event.exitPullEvents()

  else
    return UI.Page.eventHandler(self, event)
  end

  return true
end
 
function changedPage:refresh()
  local t = storage:listItems('all')
 
  if not t or Util.empty(t) then
    self:clear()
    self:centeredWrite(math.ceil(self.height/2), 'Communication failure')
    return
  end
 
  for k,v in pairs(t) do
    --v.id = v.id
    --v.dmg = v.dmg
    v.name = safeString(v.display_name)
    t[k] = Util.shallowCopy(v)
    --v.qty = v.qty
  end
 
  if not self.lastItems then
    self.lastItems = t
    self.grid:setValues({ })
  else
    local changedItems = {}
    for _,v in pairs(self.lastItems) do
      found = false
      for k2,v2 in pairs(t) do
        if v.id == v2.id and
           v.dmg == v2.dmg then
          if v.qty ~= v2.qty then
            local c = Util.shallowCopy(v2)
            c.lastQty = v.qty
            table.insert(changedItems, c)
          end
          table.remove(t, k2)
          found = true
          break
        end
      end
      -- New item
      if not found then
        local c = Util.shallowCopy(v)
        c.lastQty = v.qty
        c.qty = 0
        table.insert(changedItems, c)
      end
    end
    -- No items left
    for k,v in pairs(t) do
      v.lastQty = 0
      table.insert(changedItems, v)
    end
    for k,v in pairs(changedItems) do
      local diff = v.qty - v.lastQty
      local ind = '+'
      if v.qty < v.lastQty then
        ind = ''
      end
      v.change  = ind .. diff
      v.dispQty = v.qty
      if v.dispQty > 10000 then
        v.dispQty = math.floor(v.qty / 1000) .. 'k'
      end
      v.iddmg = tostring(v.id) .. ':' .. tostring(v.dmg)
    end
    self.grid:setValues(changedItems)
  end
  self:draw()
end
 
Event.addTimer(5, true, function()
  changedPage:refresh()
  changedPage:sync()
end)
 
UI:setPage(changedPage)
Event.pullEvents()
UI.term:reset()

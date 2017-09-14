requireInjector(getfenv(1))

local ChestAdapter    = require('chestAdapter18')
local Event           = require('event')
local MEAdapter       = require('meAdapter')
local RefinedAdapter  = require('refinedAdapter')
local UI              = require('ui')
local Util            = require('util')

local storage = RefinedAdapter()
if not storage:isValid() then
  storage = MEAdapter()
  if not storage:isValid() then
    storage = ChestAdapter()
  end
end

if not storage:isValid() then
  error('Not connected to a storage device')
end

multishell.setTitle(multishell.getCurrent(), 'Storage Activity')
UI:configure('StorageActivity', ...)

local changedPage = UI.Page({
  grid = UI.Grid({
    columns = {
      { heading = 'Qty',    key = 'count',       width = 5                  },
      { heading = 'Change', key = 'change',      width = 6                  },
      { heading = 'Name',   key = 'displayName', width = UI.term.width - 15 },
    },
    sortColumn = 'displayName',
    rey = -6,
  }),
  buttons = UI.Window({
    ry = -4,
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
      rex = -8,
      text = 'Reset'
    }),
    nextButton = UI.Button({
      event = 'next',
      backgroundColor = colors.lightGray,
      rx = -5,
      y = 2,
      height = 3,
      width = 5,
      text = ' > '
    })
  }),
  accelerators = {
    q = 'quit',
  }
})

function changedPage.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)

  local ind = '+'
  if row.change < 0 then
    ind = ''
  end
  row.change = ind .. Util.toBytes(row.change)
  row.count = Util.toBytes(row.count)

  return row
end

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

local function uniqueKey(item)
  return table.concat({ item.name, item.damage, item.nbtHash }, ':')
end

function changedPage:refresh()
  local t = storage:listItems()
 
  if not t or Util.empty(t) then
    self:clear()
    self:centeredWrite(math.ceil(self.height/2), 'Communication failure')
    return
  end
 
  for k,v in pairs(t) do
    t[k] = Util.shallowCopy(v)
  end
 
  if not self.lastItems then
    self.lastItems = t
    self.grid:setValues({ })
  else
    local changedItems = {}
    for _,v in pairs(self.lastItems) do
      found = false
      for k2,v2 in pairs(t) do
        if uniqueKey(v) == uniqueKey(v2) then
          if v.count ~= v2.count then
            local c = Util.shallowCopy(v2)
            c.lastCount = v.count
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
        c.lastCount = v.count
        c.count = 0
        table.insert(changedItems, c)
      end
    end
    -- No items left
    for k,v in pairs(t) do
      v.lastCount = 0
      table.insert(changedItems, v)
    end

    for k,v in pairs(changedItems) do
      v.change  = v.count - v.lastCount
    end

    self.grid:setValues(changedItems)
  end
  self.grid:draw()
end
 
Event.onInterval(5, function()
  changedPage:refresh()
  changedPage:sync()
end)
 
UI:setPage(changedPage)
UI:pullEvents()

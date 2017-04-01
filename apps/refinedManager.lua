local injector = requireInjector or load(http.get('http://pastebin.com/raw/c0TWsScv').readAll())()
require = injector(getfenv(1))
local Event = require('event')
local UI = require('ui')
local Peripheral = require('peripheral')

local controller = Peripheral.getByType('refinedstorage:controller')
if not controller then
  error('Refined storage controller not found')
end

multishell.setTitle(multishell.getCurrent(), 'Storage Manager')

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

function listItems()
  local items = { }
  local list

  pcall(function()
    list = controller.listAvailableItems()
  end)

  if list then
    for k,v in pairs(list) do
      local item = controller.findItem(v)

      if item then
        Util.merge(item, item.getMetadata())
        item.displayName = safeString(item.displayName)
        if item.maxDamage and item.maxDamage > 0 and item.damage > 0 then
          item.displayName = item.displayName .. ' (damaged)'
        end
        item.lname = item.displayName:lower()

        table.insert(items, item)
      end
    end
  end

  return items
end

function getItem(items, inItem, ignoreDamage)
  for _,item in pairs(items) do
    if item.name == inItem.name then
      if ignoreDamage and ignoreDamage == 'yes' then
        return item
      elseif item.damage == inItem.damage and item.nbtHash == inItem.nbtHash then
        return item
      end
    end
  end
end

local function uniqueKey(item)
  local key = item.name .. ':' .. item.damage
  if item.nbtHash then
    key = key .. ':' .. item.nbtHash
  end
  return key
end

function mergeResources(t)
  local resources = Util.readTable('resource.limits')
  resources = resources or { }

  for _,v in pairs(resources) do
    local item = getItem(t, v)
    if item then
      item.limit = tonumber(v.limit)
      item.low = tonumber(v.low)
      item.auto = v.auto
      item.ignoreDamage = v.ignoreDamage
    else
      v.count = 0
      v.limit = tonumber(v.limit)
      v.low = tonumber(v.low)
      v.auto = v.auto
      v.ignoreDamage = v.ignoreDamage
      table.insert(t, v)
    end
  end
end
 
function filterItems(t, filter)
  local r = {}
  if filter then
    filter = filter:lower()
    for k,v in pairs(t) do
      if  string.find(v.lname, filter) then
        table.insert(r, v)
      end
    end
  else
    return t
  end
  return r
end

function getJobList()
  local list = { }

  for _,task in pairs(controller.getCraftingTasks()) do
    table.insert(list, task.getPattern().outputs[1])
  end

  return list
end

function craftItems(itemList, allItems)

  for _,item in pairs(itemList) do

    local alreadyCrafting = false
    local jobList = getJobList()

    for _,v in pairs(jobList) do
      if v.name == item.name and v.damage == item.damage and v.nbtHash == item.nbtHash then
        alreadyCrafting = true
      end
    end

    local cItem = getItem(allItems, item)

    if alreadyCrafting then
      item.status = '(crafting)'
    elseif not cItem then
      item.status = '(no recipe)'
    else

      local count = item.count
      while count >= 1 do -- try to request smaller quantities until successful
        local s, m = pcall(function()
          item.status = '(no recipe)'
          if not cItem.craft(count) then
            item.status = '(missing ingredients)'
            error('failed')
          end
          item.status = '(crafting)'
        end)
        if s then
          break -- successfully requested crafting
        end
        count = math.floor(count / 2)
      end
    end
  end
end

function getAutocraftItems(items)
  local t = Util.readTable('resource.limits') or { }
  local itemList = { }

  for _,res in pairs(t) do

    if res.auto and res.auto == 'yes' then
      res.count = 4  -- this could be higher to increase autocrafting speed
      table.insert(itemList, res)
    end
  end
  return itemList
end

local function getItemWithQty(items, res, ignoreDamage)

  local item = getItem(items, res, ignoreDamage)

  if item then

    if ignoreDamage and ignoreDamage == 'yes' then
      local count = 0

      for _,v in pairs(items) do
        if item.name == v.name and item.nbtHash == v.nbtHash then
          if item.maxDamage > 0 or item.damage == v.damage then
            count = count + v.count
          end
        end
      end

      item.count = count
    end
  end

  return item
end

function watchResources(items)

  local itemList = { }

  local t = Util.readTable('resource.limits') or { }
  for k, res in pairs(t) do
    local item = getItemWithQty(items, res, res.ignoreDamage)
    res.limit = tonumber(res.limit)
    res.low = tonumber(res.low)
    if not item then
      item = {
        damage = res.damage,
        nbtHash = res.nbtHash,
        name = res.name,
        displayName = res.displayName,
        count = 0
      }
    end

    if res.low and item.count < res.low then
      if res.ignoreDamage and res.ignoreDamage == 'yes' then
        item.damage = 0
      end
      table.insert(itemList, {
        damage = item.damage,
        nbtHash = item.nbtHash,
        count = res.low - item.count,
        name = item.name,
        displayName = item.displayName,
        status = ''
      })
    end
  end

  return itemList
end

itemPage = UI.Page {
  backgroundColor = colors.lightGray,
  titleBar = UI.TitleBar {
    title = 'Limit Resource',
    previousPage = true,
    event = 'form_cancel',
    backgroundColor = colors.green
  },
  displayName = UI.Window {
    x = 5, y = 3, width = UI.term.width - 10, height = 3,
  },
  form = UI.Form {
    x = 4, y = 6, height = 8, rex = -4,
    [1] = UI.TextEntry {
      width = 7,
      backgroundColor = colors.gray,
      backgroundFocusColor = colors.gray,
      formLabel = 'Min', formKey = 'low', help = 'Craft if below min'
    },
    [2] = UI.Chooser {
      width = 7,
      formLabel = 'Autocraft', formKey = 'auto',
      nochoice = 'No',
      choices = {
        { name = 'Yes', value = 'yes' },
        { name = 'No', value = 'no' },
      },
      help = 'Craft until out of ingredients'
    },
    [3] = UI.Chooser {
      width = 7,
      formLabel = 'Ignore Dmg', formKey = 'ignoreDamage',
      nochoice = 'No',
      choices = {
        { name = 'Yes', value = 'yes' },
        { name = 'No', value = 'no' },
      },
      help = 'Ignore damage of item'
    },
  },
  statusBar = UI.StatusBar { }
}

function itemPage.displayName:draw()
  local item = self.parent.item
  local str = string.format('Name:   %s\nDamage: %d', item.displayName, item.damage)
  if item.nbtHash then
    str = str .. string.format('\nNBT:    %s\n', item.nbtHash)
  end
  debug(str)
  self:setCursorPos(1, 1)
  self:print(str)
end

function itemPage:enable(item)
  self.item = item

  self.form:setValues(item)
  self.titleBar.title = item.name
  self.displayName.value = item.displayName

  UI.Page.enable(self)
  self:focusFirst()
end
 
function itemPage:eventHandler(event)
  if event.type == 'form_cancel' then
    UI:setPreviousPage()

  elseif event.type == 'focus_change' then
    self.statusBar:setStatus(event.focused.help)
    self.statusBar:draw()

  elseif event.type == 'form_complete' then
    local values = self.form.values
    local t = Util.readTable('resource.limits') or { }
    for k,v in pairs(t) do
      if v.name == values.name and v.damage == values.damage then
        t[k] = nil
        break
      end
    end
    local keys = { 'name', 'displayName', 'auto', 'low', 'damage', 'maxDamage', 'nbtHash', 'limit', 'ignoreDamage' }
    local filtered = { }
    for _,key in pairs(keys) do
      filtered[key] = values[key]
    end

    if filtered.ignoreDamage and filtered.ignoreDamage == 'yes' then
      filtered.damage = 0
    end

    t[uniqueKey(filtered)] = filtered
    --table.insert(t, filtered)
    Util.writeTable('resource.limits', t)
    UI:setPreviousPage()

  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

listingPage = UI.Page {
  menuBar = UI.MenuBar {
    buttons = {
      { text = 'Forget', event = 'forget' },
    },
  },
  grid = UI.Grid {
    y = 2, height = UI.term.height - 2,
    columns = {
      { heading = 'Name', key = 'displayName', width = UI.term.width - 14 },
      { heading = 'Qty',  key = 'count',       width = 5  },
      { heading = 'Min',  key = 'low',         width = 4  },
    },
    sortColumn = 'lname',
  },
  statusBar = UI.StatusBar {
    backgroundColor = colors.gray,
    width = UI.term.width,
    filterText = UI.Text {
      x = 2, width = 6,
      value = 'Filter',
    },
    filter = UI.TextEntry {
      x = 9, rex = -12,
      limit = 50,
    },
    refresh = UI.Button {
      rx = -9, width = 8,
      text = 'Refresh', 
      event = 'refresh',
    },
  },
  accelerators = {
    r = 'refresh',
    q = 'quit',
  }
}

function listingPage.grid:getRowTextColor(row, selected)
  if row.is_craftable then -- not implemented
    return colors.yellow
  end
  return UI.Grid:getRowTextColor(row, selected)
end

function listingPage.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)
  row.count = Util.toBytes(row.count)
  if row.low then
    row.low = Util.toBytes(row.low)
  end
  if row.limit then
    row.limit = Util.toBytes(row.limit)
  end
  return row
end

function listingPage.statusBar:draw()
  return UI.Window.draw(self)
end

function listingPage.statusBar.filter:eventHandler(event)
  if event.type == 'mouse_rightclick' then
    self.value = ''
    self:draw()
    local page = UI:getCurrentPage()
    page.filter = nil
    page:applyFilter()
    page.grid:draw()
    page:setFocus(self)
  end
  return UI.TextEntry.eventHandler(self, event)
end

function listingPage:eventHandler(event)
  if event.type == 'quit' then
    Event.exitPullEvents()

  elseif event.type == 'grid_select' then
    local selected = event.selected
    UI:setPage('item', selected)

  elseif event.type == 'refresh' then
    self:refresh()
    self.grid:draw()

  elseif event.type == 'forget' then
    local item = self.grid:getSelected()
    if item then

      local resources = Util.readTable('resource.limits') or { }
      resources[uniqueKey(item)] = nil
      Util.writeTable('resource.limits', resources)

      self.statusBar:timedStatus('Forgot: ' .. item.name, 3)
      self:refresh()
      self.grid:draw()
    end

  elseif event.type == 'text_change' then 
    self.filter = event.text
    if #self.filter == 0 then
      self.filter = nil
    end
    self:applyFilter()
    self.grid:draw()
    self.statusBar.filter:focus()

  else
    UI.Page.eventHandler(self, event)
  end
  return true
end

function listingPage:enable()
  self:refresh()
  self:setFocus(self.statusBar.filter)
  UI.Page.enable(self)
end

function listingPage:refresh()
  self.allItems = listItems()
  mergeResources(self.allItems)
  self:applyFilter()
end

function listingPage:applyFilter()
  local t = filterItems(self.allItems, self.filter)
  self.grid:setValues(t)
end

local nullDevice = {
    setCursorPos = function(...) end,
    write = function(...) end,
    getSize = function() return 13, 20 end,
    isColor = function() return false end,
    setBackgroundColor = function(...) end,
    setTextColor = function(...) end,
    clear = function(...) end,
    sync = function(...) end,
}

local function jobMonitor(jobList)

  local mon = Peripheral.getByType('monitor')

  if mon then
    mon = UI.Device({
      device = mon,
      textScale = .5,
    })
  else
    mon = UI.Device({
      device = nullDevice
    })
  end

  jobListGrid = UI.Grid {
    parent = mon,
    sortColumn = 'displayName',
    columns = {
      { heading = 'Qty',      key = 'count',    width = 6                  },
      { heading = 'Crafting', key = 'displayName',   width = mon.width / 2 - 10 },
      { heading = 'Status',   key = 'status', width = mon.width - 10     },
    },
  }
end

local function jobMonitor(jobList)

  local mon = Peripheral.getByType('monitor')
  local nullDevice = {
      setCursorPos = function(...) end,
      write = function(...) end,
      getSize = function() return 13, 20 end,
      isColor = function() return false end,
      setBackgroundColor = function(...) end,
      setTextColor = function(...) end,
      clear = function(...) end,
      sync = function(...) end,
      blit = function(...) end,
  }

  if mon then
    mon = UI.Device({
      device = mon,
      textScale = .5,
    })
  else
    mon = UI.Device({
      device = nullDevice
    })
  end

  jobListGrid = UI.Grid {
    parent = mon,
    sortColumn = 'displayName',
    columns = {
      { heading = 'Qty',      key = 'count',    width = 6                  },
      { heading = 'Crafting', key = 'displayName',   width = mon.width / 2 - 10 },
      { heading = 'Status',   key = 'status', width = mon.width - 10     },
    },
  }

  return jobListGrid
end

UI:setPages({
  listing = listingPage,
  item = itemPage,
})

UI:setPage(listingPage)
listingPage:setFocus(listingPage.statusBar.filter)

local jobListGrid = jobMonitor()
jobListGrid:draw()
jobListGrid:sync()

function craftingThread()

  while true do
    os.sleep(5)

    pcall(function()

      local items = listItems()

      if controller.getNetworkEnergyStored() == 0 then
        jobListGrid.parent:clear()
        jobListGrid.parent:centeredWrite(math.ceil(jobListGrid.parent.height/2), 'Power failure')
        jobListGrid:sync()

      elseif Util.size(items) == 0 then
        jobListGrid.parent:clear()
        jobListGrid.parent:centeredWrite(math.ceil(jobListGrid.parent.height/2), 'No items in system')
        jobListGrid:sync()

      else
        local itemList = watchResources(items)
        jobListGrid:setValues(itemList)
        jobListGrid:draw()
        jobListGrid:sync()
        craftItems(itemList, items)
        jobListGrid:update()
        jobListGrid:draw()
        jobListGrid:sync()

        itemList = getAutocraftItems(items) -- autocrafted items don't show on job monitor
        craftItems(itemList, items) 
      end
    end)
  end
end

Event.pullEvents(craftingThread)

UI.term:reset()
jobListGrid.parent:reset()

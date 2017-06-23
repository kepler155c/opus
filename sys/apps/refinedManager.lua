local injector = requireInjector or load(http.get('http://pastebin.com/raw/c0TWsScv').readAll())()
require = injector(getfenv(1))

local UI = require('ui')
local RefinedProvider = require('refinedProvider')
local Terminal = require('terminal')
local Peripheral = require('peripheral')

local controller = RefinedProvider()
if not controller:isValid() then
  error('Refined storage controller not found')
end

multishell.setTitle(multishell.getCurrent(), 'Storage Manager')

function getItem(items, inItem, ignoreDamage)
  for _,item in pairs(items) do
    if item.name == inItem.name then
      if ignoreDamage then
        return item
      elseif item.damage == inItem.damage and item.nbtHash == inItem.nbtHash then
        return item
      end
    end
  end
end

local function uniqueKey(item)
  return table.concat({ item.name, item.damage, item.nbtHash }, ':')
end

function mergeResources(t)
  local resources = Util.readTable('resource.limits') or { }

  for _,v in pairs(resources) do
    v.low = tonumber(v.low) -- backwards compatibility
    local item = getItem(t, v)
    if item then
      item.low = v.low
      item.auto = v.auto
      item.ignoreDamage = v.ignoreDamage
      item.rsControl = v.rsControl
      item.rsDevice = v.rsDevice
      item.rsSide = v.rsSide
    else
      v.count = 0
      table.insert(t, v)
    end
  end

  for _,v in pairs(t) do
    v.lname = v.displayName:lower()
  end
end
 
function filterItems(t, filter)
  if filter then
    local r = {}
    filter = filter:lower()
    for k,v in pairs(t) do
      if string.find(v.lname, filter) then
        table.insert(r, v)
      end
    end
    return r
  end
  return t
end

function craftItems(itemList, allItems)

  for _,item in pairs(itemList) do
    local cItem = getItem(allItems, item)

    if controller:isCrafting(item) then
      item.status = '(crafting)'
    elseif item.rsControl then
      item.status = 'Activated'
    elseif not cItem then
      item.status = '(no recipe)'
    else

      local count = item.count
      while count >= 1 do -- try to request smaller quantities until successful
        local s, m = pcall(function()
          item.status = '(no recipe)'
          if not controller:craft(cItem, count) then
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

function getAutocraftItems()
  local t = Util.readTable('resource.limits') or { }
  local itemList = { }

  for _,res in pairs(t) do

    if res.auto then
      res.count = 4  -- this could be higher to increase autocrafting speed
      table.insert(itemList, res)
    end
  end
  return itemList
end

local function getItemWithQty(items, res, ignoreDamage)

  local item = getItem(items, res, ignoreDamage)

  if item then

    if ignoreDamage then
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
    res.low = tonumber(res.low) -- backwards compatibility
    local item = getItemWithQty(items, res, res.ignoreDamage)
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
      if res.ignoreDamage then
        item.damage = 0
      end
      table.insert(itemList, {
        damage = item.damage,
        nbtHash = item.nbtHash,
        count = res.low - item.count,
        name = item.name,
        displayName = item.displayName,
        status = '',
        rsControl = res.rsControl,
      })
    end

    if res.rsControl and res.rsDevice and res.rsSide then
      pcall(function() 
        device[res.rsDevice].setOutput(res.rsSide, item.count < res.low)
      end)
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
    x = 5, y = 2, width = UI.term.width - 10, height = 3,
  },
  form = UI.Form {
    x = 4, y = 4, height = 10, rex = -4,
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
        { name = 'Yes', value = true },
        { name = 'No', value = false },
      },
      help = 'Craft until out of ingredients'
    },
    [3] = UI.Chooser {
      width = 7,
      formLabel = 'Ignore Dmg', formKey = 'ignoreDamage',
      nochoice = 'No',
      choices = {
        { name = 'Yes', value = true },
        { name = 'No', value = false },
      },
      help = 'Ignore damage of item'
    },
    [4] = UI.Chooser {
      width = 7,
      formLabel = 'RS Control', formKey = 'rsControl',
      nochoice = 'No',
      choices = {
        { name = 'Yes', value = true },
        { name = 'No', value = false },
      },
      help = 'Control via redstone'
    },
    [5] = UI.Chooser {
      width = 25,
      formLabel = 'RS Device', formKey = 'rsDevice',
      --choices = devices,
      help = 'Redstone Device'
    },
    [6] = UI.Chooser {
      width = 10,
      formLabel = 'RS Side', formKey = 'rsSide',
      --nochoice = 'No',
      choices = {
        { name = 'up', value = 'up' },
        { name = 'down', value = 'down' },
        { name = 'east', value = 'east' },
        { name = 'north', value = 'north' },
        { name = 'west', value = 'west' },
        { name = 'south', value = 'south' },
      },
      help = 'Output side'
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
  self:setCursorPos(1, 1)
  self:print(str)
end

function itemPage:enable(item)
  self.item = item

  self.form:setValues(item)
  self.titleBar.title = item.name

  local devices = self.form[5].choices
  Util.clear(devices)
  for _,device in pairs(device) do
    if device.setOutput then
      table.insert(devices, { name = device.name, value = device.name })
    end
  end

  if Util.size(devices) == 0 then
    table.insert(devices, { name = 'None found', values = '' })
  end

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
    local keys = { 'name', 'displayName', 'auto', 'low', 'damage',
                   'maxDamage', 'nbtHash', 'ignoreDamage',
                   'rsControl', 'rsDevice', 'rsSide', }

    local filtered = { }
    for _,key in pairs(keys) do
      filtered[key] = values[key]
    end
    filtered.low = tonumber(filtered.low)

    filtered.ignoreDamage = filtered.ignoreDamage == true
    filtered.auto = filtered.auto == true
    filtered.rsControl = filtered.rsControl == true

    if filtered.ignoreDamage then
      filtered.damage = 0
    end

    t[uniqueKey(filtered)] = filtered
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
    UI:exitPullEvents()

  elseif event.type == 'grid_select' then
    local selected = event.selected
    UI:setPage('item', selected)

  elseif event.type == 'refresh' then
    self:refresh()
    self.grid:draw()
    self.statusBar.filter:focus()

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
  self.allItems = controller:listItems()
  mergeResources(self.allItems)
  self:applyFilter()
end

function listingPage:applyFilter()
  local t = filterItems(self.allItems, self.filter)
  self.grid:setValues(t)
end

local function jobMonitor(jobList)

  local mon = Peripheral.getByType('monitor')

  if mon then
    mon = UI.Device({
      device = device.monitor,
      textScale = .5,
    })
  else
    mon = UI.Device({
      device = Terminal.getNullTerm(term.current())
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

    --pcall(function()

      local items = controller:listItems()

      if not controller:isOnline() then
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
        --jobListGrid:update()
        jobListGrid:draw()
        jobListGrid:sync()

        itemList = getAutocraftItems() -- autocrafted items don't show on job monitor
        craftItems(itemList, items) 
      end
    --end)
  end
end

UI:pullEvents(craftingThread)

UI.term:reset()
jobListGrid.parent:reset()

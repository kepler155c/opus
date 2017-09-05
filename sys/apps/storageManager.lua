requireInjector(getfenv(1))

local Config = require('config')
local Event  = require('event')
local Logger = require('logger')
local ME     = require('me')
local UI     = require('ui')
local Util   = require('util')

-- Must be a crafty turtle with duck antenna !
-- 3 wide monitor (any side of turtle)

-- Config location is /sys/config/storageMonitor
-- adjust directions in that file if needed

local config = {
  trashDirection = 'up',       -- trash /chest in relation to interface
  turtleDirection = 'down',    -- turtle in relation to interface
  noCraftingStorage = 'false'  -- no ME crafting (or ability to tell if powered - use with caution)
}

Config.load('storageMonitor', config)

if not device.tileinterface then
  error('ME interface not found')
end

local duckAntenna

if device.workbench then

  local oppositeSide = {
    [ 'left' ] = 'right',
    [ 'right' ] = 'left'
  }

  local duckAntennaSide = oppositeSide[device.workbench.side]
  duckAntenna = peripheral.wrap(duckAntennaSide)
end
--if not device.monitor then
--  error('Monitor not found')
--end

ME.setDevice(device.tileinterface)

local jobListGrid
local craftingPaused = false

multishell.setTitle(multishell.getCurrent(), 'Storage Manager')

Logger.disable()

function getItem(items, inItem, ignore_dmg)
  for _,item in pairs(items) do
    if item.id == inItem.id then
      if ignore_dmg and ignore_dmg == 'yes' then
        return item
      elseif item.dmg == inItem.dmg and item.nbt_hash == inItem.nbt_hash then
        return item
      end
    end
  end
end

local function uniqueKey(item)
  local key = item.id .. ':' .. item.dmg
  if item.nbt_hash then
    key = key .. ':' .. item.nbt_hash
  end
  return key
end

function mergeResources(t)
  local resources = Util.readTable('resource.limits')
  resources = resources or { }

  for _,item in pairs(t) do
    item.has_recipe = false
  end

  for _,v in pairs(resources) do
    local item = getItem(t, v)
    if item then
      item.limit = tonumber(v.limit)
      item.low = tonumber(v.low)
      item.auto = v.auto
      item.ignore_dmg = v.ignore_dmg
    else
      v.qty = 0
      v.limit = tonumber(v.limit)
      v.low = tonumber(v.low)
      v.auto = v.auto
      v.ignore_dmg = v.ignore_dmg
      table.insert(t, v)
    end
  end

  recipes = Util.readTable('recipes') or { }

  for _,v in pairs(recipes) do
    local item = getItem(t, v)
    if item then
      item.has_recipe = true
    else
      v.qty = 0
      v.limit = nil
      v.low = nil
      v.has_recipe = true
      v.auto = 'no'
      v.ignore_dmg = 'no'
      v.has_recipe = 'true'
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

function sumItems(items)
  local t = {}

  for _,item in pairs(items) do
    local key = uniqueKey(item)
    local summedItem = t[key]
    if summedItem then
      summedItem.qty = summedItem.qty + item.qty
    else
      summedItem = Util.shallowCopy(item)
      t[key] = summedItem
    end
  end

  return t
end

function isGridClear()
  for i = 1, 16 do
    if turtle.getItemCount(i) ~= 0 then
      return false
    end
  end
  return true
end

local function clearGrid()
  for i = 1, 16 do
    local count = turtle.getItemCount(i)
    if count > 0 then
      ME.insert(i, count, config.turtleDirection)
      if turtle.getItemCount(i) ~= 0 then
        return false
      end
    end
  end
  return true
end

function turtleCraft(recipe, originalItem)

  for k,v in pairs(recipe.ingredients) do

    -- ugh
    local dmg = v.dmg

    if v.max_dmg and v.max_dmg > 0 then
      local item = ME.getItemDetail({ id = v.id, nbt_hash = v.nbt_hash }, false)
      if item then
        dmg = item.dmg
      end
    end

    if not ME.extract(v.id, dmg, v.nbt_hash, v.qty, config.turtleDirection, k) then
      clearGrid()
      originalItem.status = v.name .. ' (extract failed)'
      return false
    end
  end

  if not turtle.craft() then
    clearGrid()
    return false
  end

  clearGrid()
  return true
end

function craftItem(items, recipes, item, originalItem, itemList)

  local key = uniqueKey(item)
  local recipe = recipes[key]

  if recipe then

    if not isGridClear() then
      return
    end

    local summedItems = sumItems(recipe.ingredients)

    for i = 1, math.ceil(item.qty / recipe.qty) do

      local failed = false -- try to craft all components (use all CPUs available)

      for _,ingredient in pairs(summedItems) do
        local ignore_dmg = 'no'
        if ingredient.max_dmg and ingredient.max_dmg > 0 then
          ignore_dmg = 'yes'
        end
        local qty = ME.getItemCount(ingredient.id, ingredient.dmg, ingredient.nbt_hash, ignore_dmg)
        if qty < ingredient.qty then
          originalItem.status = ingredient.name .. ' (crafting)'
          ingredient.qty = ingredient.qty - qty
          if not craftItem(items, recipes, ingredient, originalItem, itemList) then
            failed = true
          end
        end
      end

      if failed then
        return false
      end

      if not failed and not turtleCraft(recipe, originalItem) then
        Logger.debug('turtle failed to craft ' .. item.name)
        return false
      end
    end

    return true

  else

    local meItem = getItem(items, item)
    if not meItem or not meItem.is_craftable then

      if item.id == originalItem.id and item.dmg == originalItem.dmg then
        originalItem.status = '(not craftable)'
      else
        originalItem.status = item.name .. ' (missing)'
      end

    else

      if item.id == originalItem.id and item.dmg == originalItem.dmg then
        item.meCraft = true
        return false
      end

      -- find it in the list of items to be crafted
      for _,v in pairs(itemList) do
        if v.id == item.id and v.dmg == item.dmg and v.nbt_hash == item.nbt_hash then
          v.qty = item.qty + v.qty
          return false
        end
      end
      -- add to the item list
      table.insert(itemList, {
        id = item.id,
        dmg = item.dmg,
        nbt_hash = item.nbt_hash,
        qty = item.qty,
        name = item.name,
        meCraft = true,
        status = ''
      })
    end
  end

  return false
end

function craftItems(itemList)

  local recipes = Util.readTable('recipes') or { }
  local items = ME.getAvailableItems()

  -- turtle craft anything we can, build up list for ME items
  local keys = Util.keys(itemList)
  for _,key in pairs(keys) do
    local item = itemList[key]
    craftItem(items, recipes, item, item, itemList)
  end

  -- second pass is to request crafting from ME with aggregated items
  for _,item in pairs(itemList) do
    if item.meCraft then

      local alreadyCrafting = false
      local jobList = ME.getJobList()

      for _,v in pairs(jobList) do
        if v.id == item.id and v.dmg == item.dmg and v.nbt_hash == item.nbt_hash then
          alreadyCrafting = true
        end
      end

      if alreadyCrafting then
        item.status = '(crafting)'
      elseif not ME.isCPUAvailable() then
        item.status = '(waiting)'
      else
        item.status = '(failed)'

        local qty = item.qty
        while qty >= 1 do -- try to request smaller quantities until successful
          if ME.craft(item.id, item.dmg, item.nbt_hash, qty) then
            item.status = '(crafting)'
            break -- successfully requested crafting
          end
          qty = math.floor(qty / 2)
        end
      end
    end
  end
end

-- AE 1 (obsolete)
function isCrafting(jobList, id, dmg)
  for _, job in pairs(jobList) do
    if job.id == id and job.dmg == dmg then
      return job
    end
  end
end

local nullDevice = {
    setCursorPos = function(...) end,
    write = function(...) end,
    getSize = function() return 13, 20 end,
    isColor = function() return false end,
    setBackgroundColor = function(...) end,
    setTextColor = function(...) end,
    clear = function(...) end,
}

local function jobMonitor(jobList)

  local mon

  if device.monitor then
    mon = UI.Device({
      deviceType = 'monitor',
      textScale = .5,
    })
  else
    mon = UI.Device({
      device = nullDevice
    })
  end

  jobListGrid = UI.Grid({
    parent = mon,
    sortColumn = 'name',
    columns = {
      { heading = 'Qty',      key = 'qty',    width = 6                  },
      { heading = 'Crafting', key = 'name',   width = mon.width / 2 - 10 },
      { heading = 'Status',   key = 'status', width = mon.width - 10     },
    },
  })
end

function getAutocraftItems(items)
  local t = Util.readTable('resource.limits') or { }
  local itemList = { }

  for _,res in pairs(t) do

    if res.auto and res.auto == 'yes' then
      res.qty = 4  -- this could be higher to increase autocrafting speed
      table.insert(itemList, res)
    end
  end
  return itemList
end

local function getItemWithQty(items, res, ignore_dmg)

  local item = getItem(items, res, ignore_dmg)

  if item then

    if ignore_dmg and ignore_dmg == 'yes' then
      local qty = 0

      for _,v in pairs(items) do
        if item.id == v.id and item.nbt_hash == v.nbt_hash then
          if item.max_dmg > 0 or item.dmg == v.dmg then
            qty = qty + v.qty
          end
        end
      end

      item.qty = qty
    end
  end

  return item
end

function watchResources(items)

  local itemList = { }

  local t = Util.readTable('resource.limits') or { }
  for k, res in pairs(t) do
    local item = getItemWithQty(items, res, res.ignore_dmg)
    res.limit = tonumber(res.limit)
    res.low = tonumber(res.low)
    if not item then
      item = {
        id = res.id,
        dmg = res.dmg,
        nbt_hash = res.nbt_hash,
        name = res.name,
        qty = 0
      }
    end

    if res.limit and item.qty > res.limit then
      Logger.debug("Purging " .. item.qty-res.limit .. " " .. res.name)
      if not ME.extract(item.id, item.dmg, item.nbt_hash, item.qty - res.limit, config.trashDirection) then
        Logger.debug('Failed to purge ' .. res.name)
      end

    elseif res.low and item.qty < res.low then
      if res.ignore_dmg and res.ignore_dmg == 'yes' then
        item.dmg = 0
      end
      table.insert(itemList, {
        id = item.id,
        dmg = item.dmg,
        nbt_hash = item.nbt_hash,
        qty = res.low - item.qty,
        name = item.name,
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
  idField = UI.Text {
    x = 5, y = 3, width = UI.term.width - 10,
  },
  form = UI.Form {
    x = 4, y = 4, height = 8, rex = -4,
    [1] = UI.TextEntry {
      width = 7,
      backgroundColor = colors.gray,
      backgroundFocusColor = colors.gray,
      formLabel = 'Min', formKey = 'low', help = 'Craft if below min'
    },
    [2] = UI.TextEntry {
      width = 7,
      backgroundColor = colors.gray,
      backgroundFocusColor = colors.gray,
      formLabel = 'Max', formKey = 'limit', help = 'Eject if above max'
    },
    [3] = UI.Chooser {
      width = 7,
      formLabel = 'Autocraft', formKey = 'auto',
      nochoice = 'No',
      choices = {
        { name = 'Yes', value = 'yes' },
        { name = 'No', value = 'no' },
      },
      help = 'Craft until out of ingredients'
    },
    [4] = UI.Chooser {
      width = 7,
      formLabel = 'Ignore Dmg', formKey = 'ignore_dmg',
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

function itemPage:enable()
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
      if v.id == values.id and v.dmg == values.dmg then
        table.remove(t, k)
        break
      end
    end
    local keys = { 'name', 'auto', 'id', 'low', 'dmg', 'max_dmg', 'nbt_hash', 'limit', 'ignore_dmg' }
    local filtered = { }
    for _,key in pairs(keys) do
      filtered[key] = values[key]
    end

    table.insert(t, filtered)
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
      { text = 'Learn',  event = 'learn'  },
      { text = 'Forget', event = 'forget' },
    },
  },
  grid = UI.Grid {
    y = 2, height = UI.term.height - 2,
    columns = {
      { heading = 'Name', key = 'name' , width = 22 },
      { heading = 'Qty',  key = 'qty'  , width = 5  },
      { heading = 'Min',  key = 'low'  , width = 4  },
      { heading = 'Max',  key = 'limit', width = 4  },
    },
    sortColumn = 'name',
  },
  statusBar = UI.StatusBar {
    backgroundColor = colors.gray,
    width = UI.term.width,
    filterText = UI.Text {
      x = 2, width = 6,
      value = 'Filter',
    },
    filter = UI.TextEntry {
      x = 9, width = 19,
      limit = 50,
    },
    refresh = UI.Button {
      x = 31, width = 8,
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
  if row.is_craftable then
    return colors.yellow
  end
  if row.has_recipe then
    if selected then
      return colors.blue
    end
    return colors.lightBlue
  end
  return UI.Grid:getRowTextColor(row, selected)
end

function listingPage.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)
  row.qty = Util.toBytes(row.qty)
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
    itemPage.form:setValues(selected)
    itemPage.titleBar.title = selected.name
    itemPage.idField.value = selected.id
    UI:setPage('item')

  elseif event.type == 'refresh' then
    self:refresh()
    self.grid:draw()

  elseif event.type == 'learn' then
    if not duckAntenna then
      self.statusBar:timedStatus('Missing peripherals', 3)
    else
      UI:setPage('craft')
    end

  elseif event.type == 'forget' then
    local item = self.grid:getSelected()
    if item then
      local recipes = Util.readTable('recipes') or { }
      local key = uniqueKey(item)
      local recipe = recipes[key]

      if recipe then
        recipes[key] = nil
        Util.writeTable('recipes', recipes)
      end

      local resources = Util.readTable('resource.limits') or { }
      for k,v in pairs(resources) do
        if v.id == item.id and v.dmg == item.dmg then
          table.remove(resources, k)
          Util.writeTable('resource.limits', resources)
          break
        end
      end

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
  self.allItems = ME.getAvailableItems('all')

  mergeResources(self.allItems)

  Util.each(self.allItems, function(item)
    item.lname = item.name:lower()
  end)

  self:applyFilter()
end

function listingPage:applyFilter()
  local t = filterItems(self.allItems, self.filter)
  self.grid:setValues(t)
end

-- without duck antenna
local function getTurtleInventory()
  local inventory = { }
  for i = 1,16 do
    if turtle.getItemCount(i) > 0 then
      turtle.select(i)
      local item = turtle.getItemDetail()
      inventory[i] = {
        id = item.name,
        dmg = item.damage,
        qty = item.count,
        name = item.name,
      }
    end
  end
  return inventory
end

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

local function filter(t, filter)
  local keys = Util.keys(t)
  for _,key in pairs(keys) do
    if not Util.key(filter, key) then
      t[key] = nil
    end
  end
end

local function learnRecipe(page)
  local t = Util.readTable('recipes') or { }
  local recipe = { }
  local ingredients = duckAntenna.getAllStacks(false) -- getTurtleInventory()
  if  ingredients then
    turtle.select(1)
    if turtle.craft() then
      recipe = duckAntenna.getAllStacks(false) -- getTurtleInventory()
      if recipe and recipe[1] then
        recipe = recipe[1]
        local key = uniqueKey(recipe)

        clearGrid()

        recipe.name = safeString(recipe.display_name)
        filter(recipe, { 'name', 'id', 'dmg', 'nbt_hash', 'qty', 'max_size' })

        for _,ingredient in pairs(ingredients) do
          ingredient.name = safeString(ingredient.display_name)
          filter(ingredient, { 'name', 'id', 'dmg', 'nbt_hash', 'qty', 'max_size', 'max_dmg' })

          if ingredient.max_dmg > 0 then -- let's try this...
            ingredient.dmg = 0
          end
        end
        recipe.ingredients = ingredients
        recipe.ignore_dmg = 'no'

        t[key] = recipe

        Util.writeTable('recipes', t)
        listingPage.statusBar.filter:setValue(recipe.name)
        listingPage.statusBar:timedStatus('Learned: ' .. recipe.name, 3)
        listingPage.filter = recipe.name
        listingPage:refresh()
        listingPage.grid:draw()

        return true
      end
    else
      page.statusBar:timedStatus('Failed to craft', 3)
    end
  else
    page.statusBar:timedStatus('No recipe defined', 3)
  end
end

craftPage = UI.Dialog {
  height = 7, width = UI.term.width - 6,
  backgroundColor = colors.lightGray,
  titleBar = UI.TitleBar {
    title = 'Learn Recipe',
    previousPage = true,
  },
  idField = UI.Text {
    x = 5,
    y = 3,
    width = UI.term.width - 10,
    value = 'Place recipe in turtle'
  },
  accept = UI.Button {
    rx = -13, ry = -2,
    text = 'Ok', event = 'accept',
  },
  cancel = UI.Button {
    rx = -8, ry = -2,
    text = 'Cancel', event = 'cancel'
  },
  statusBar = UI.StatusBar {
    status = 'Crafting paused'
  }
}

function craftPage:enable()
  craftingPaused = true
  self:focusFirst()
  UI.Dialog.enable(self)
end

function craftPage:disable()
  craftingPaused = false
  UI.Dialog.disable(self)
end
 
function craftPage:eventHandler(event)
  if event.type == 'cancel' then
    UI:setPreviousPage()
  elseif event.type == 'accept' then
    if learnRecipe(self) then
      UI:setPreviousPage()
    end
  else
    return UI.Dialog.eventHandler(self, event)
  end
  return true
end

UI:setPages({
  listing = listingPage,
  item = itemPage,
  craft = craftPage,
})

UI:setPage(listingPage)
listingPage:setFocus(listingPage.statusBar.filter)

clearGrid()
jobMonitor()
jobListGrid:draw()
jobListGrid:sync()

Event.onInterval(5, function()

  if not craftingPaused then

    local items = ME.getAvailableItems()
    
    if Util.size(items) == 0 then
      jobListGrid.parent:clear()
      jobListGrid.parent:centeredWrite(math.ceil(jobListGrid.parent.height/2), 'No items in system')
      jobListGrid:sync()
    
    elseif config.noCraftingStorage ~= 'true' and #ME.getCraftingCPUs() <= 0 then  -- only way to determine if AE is online
      jobListGrid.parent:clear()
      jobListGrid.parent:centeredWrite(math.ceil(jobListGrid.parent.height/2), 'Power failure')
      jobListGrid:sync()

    else
      local itemList = watchResources(items)
      jobListGrid:setValues(itemList)
      jobListGrid:draw()
      jobListGrid:sync()
      craftItems(itemList)
      jobListGrid:update()
      jobListGrid:draw()
      jobListGrid:sync()

      itemList = getAutocraftItems(items) -- autocrafted items don't show on job monitor
      craftItems(itemList) 
    end
  end
end)

UI:pullEvents()
jobListGrid.parent:reset()

requireInjector(getfenv(1))

local ChestAdapter   = require('chestAdapter18')
local Config         = require('config')
local Craft          = require('turtle.craft')
local Event          = require('event')
local itemDB         = require('itemDB')
local Peripheral     = require('peripheral')
local RefinedAdapter = require('refinedAdapter')
local Terminal       = require('terminal')
local UI             = require('ui')
local Util           = require('util')

multishell.setTitle(multishell.getCurrent(), 'Resource Manager')

-- 3 wide monitor (any side of turtle)

-- Config location is /sys/config/resourceManager
-- adjust directions in that file if needed

local config = {
  trashDirection = 'up',    -- trash /chest in relation to chest
  turtleDirection = 'down',    -- turtle in relation to chest
}

Config.load('resourceManager', config)

local controller = RefinedAdapter()
if not controller:isValid() then
--  error('Refined storage controller not found')
  controller = nil
end

local chestAdapter = ChestAdapter({ direction = 'west', wrapSide = 'back' })
local turtleChestAdapter = ChestAdapter({ direction = 'up', wrapSide = 'bottom' })

local RESOURCE_FILE = 'usr/etc/resources.db'
local RECIPES_FILE = 'sys/etc/recipes.db'

local jobListGrid
local craftingPaused = false
local recipes = Util.readTable(RECIPES_FILE) or { }
local resources = Util.readTable(RESOURCE_FILE) or { }

Craft.setRecipes(recipes)

for _,r in pairs(resources) do
  r.maxDamage = nil
  r.displayName = nil
  r.count = nil
  r.lname = nil
  r.has_recipe = nil

  if not r.ignoreDamage then
    r.ignoreDamage = nil
  end

  if not r.auto then
    r.auto = nil
  end
end
Util.writeTable(RESOURCE_FILE, resources)

local function getItem(items, inItem, ignoreDamage)
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

local function splitKey(key)
  local t = Util.split(key, '(.-):')
  local item = { }
  if #t[#t] > 2 then
    item.nbtHash = table.remove(t)
  end
  item.damage = tonumber(table.remove(t))
  item.name = table.concat(t, ':')
  return item
end

local function getItemQuantity(items, item)
  item = getItem(items, item)
  if item then
    return item.count
  end
  return 0
end

local function getItemDetails(items, item)
  local cItem = getItem(items, item)
  if cItem then
    return cItem
  end
  cItem = itemDB:get(itemDB:makeKey(item))
  if cItem then
    return { count = 0, maxCount = cItem.maxCount }
  end
  return { count = 0, maxCount = 64 }
end

local function uniqueKey(item)
  return table.concat({ item.name, item.damage, item.nbtHash }, ':')
end

local function getName(item)
  local detail = itemDB:get(itemDB:makeKey(item))
  if detail then
    return detail.displayName
  end
  return item.name .. ':' .. item.damage
end

local function mergeResources(t)
  for _,v in pairs(resources) do
    local item = getItem(t, v)
    if item then
      Util.merge(item, v)
    else
      item = Util.shallowCopy(v)
      item.count = 0
      table.insert(t, item)
    end
  end

  for k in pairs(recipes) do
    local v = splitKey(k)
    local item = getItem(t, v)
    if not item then
      item = Util.shallowCopy(v)
      item.count = 0
      table.insert(t, item)
    end
    item.has_recipe = true
  end

  for _,v in pairs(t) do
    if not v.displayName then
      v.displayName = getName(v)
    end
    v.lname = v.displayName:lower()
  end
end
 
local function filterItems(t, filter)
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

local function sumItems3(ingredients, items, summedItems, count)

  local canCraft = 0
  for _,key in pairs(ingredients) do
    local item = splitKey(key)
    local summedItem = summedItems[key]
    if not summedItem then
      summedItem = Util.shallowCopy(item)
      summedItem.recipe = recipes[key]
      summedItem.count = getItemQuantity(items, summedItem)
      summedItems[key] = summedItem
    end
    summedItem.count = summedItem.count - count
    if summedItem.recipe and summedItem.count < 0 then
      local need = math.ceil(-summedItem.count / summedItem.recipe.count)
      summedItem.count = 0
      sumItems3(summedItem.recipe.ingredients, items, summedItems, need)
    end
  end
end

local function isGridClear()
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
      chestAdapter:insert(i, count)
      if turtle.getItemCount(i) ~= 0 then
        return false
      end
    end
  end
  return true
end

local function addCraftingRequest(item, craftList, count)
  local key = uniqueKey(item)
  local request = craftList[key]
  if not craftList[key] then
    request = { name = item.name, damage = item.damage, nbtHash = nbtHash, count = 0 }
    request.displayName = getName(request)
    craftList[key] = request
  end
  request.count = request.count + count
end

local function craftItem(recipe, items, originalItem, craftList, count)

  if craftingPaused or not device.workbench or not isGridClear() then
    return
  end

  local toCraft = Craft.getCraftableAmount(recipe, count, items)

  if toCraft > 0 then
    Craft.craftRecipe(recipe, toCraft, chestAdapter)
    clearGrid()
    items = chestAdapter:listItems()
  end

  count = count - toCraft

  if count > 0 then
    local summedItems = { }
    sumItems3(recipe.ingredients, items, summedItems, math.ceil(count / recipe.count))

    for key,ingredient in pairs(summedItems) do
      if not ingredient.recipe and ingredient.count < 0 then
        addCraftingRequest(ingredient, craftList, -ingredient.count)
      end
    end
  end
end

local function craftItems(craftList, allItems)

  for _,key in pairs(Util.keys(craftList)) do
    local item = craftList[key]
    local recipe = recipes[key]
    if recipe then
      craftItem(recipe, allItems, item, craftList, item.count)
      allItems = chestAdapter:listItems() -- refresh counts
    elseif item.rsControl then
      item.status = 'Activated'
    end
  end

  for key,item in pairs(craftList) do

    if not recipes[key] then
      if not controller then
        item.status = '(no recipe)'
      else
        if controller:isCrafting(item) then
          item.status = '(crafting)'
        else

          local count = item.count
          while count >= 1 do -- try to request smaller quantities until successful
            local s, m = pcall(function()
              item.status = '(no recipe)'
              if not controller:craft(item, count) then
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
  end
end

local function jobMonitor(jobList)

  local mon = Peripheral.getByType('monitor')

  if mon then
    mon = UI.Device({
      device = mon,
      textScale = .5,
    })
  else
    mon = UI.Device({
      device = Terminal.getNullTerm(term.current())
    })
  end

  jobListGrid = UI.Grid({
    parent = mon,
    sortColumn = 'displayName',
    columns = {
      { heading = 'Qty',      key = 'count',       width = 6                  },
      { heading = 'Crafting', key = 'displayName', width = mon.width / 2 - 10 },
      { heading = 'Status',   key = 'status',      width = mon.width - 10     },
    },
  })
end

local function getAutocraftItems()
  local craftList = { }

  for _,res in pairs(resources) do

    if res.auto then
      res.count = 4  -- this could be higher to increase autocrafting speed
      local key = uniqueKey(res)
      craftList[key] = res
    end
  end
  return craftList
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

local function watchResources(items)

  local craftList = { }

  for k, res in pairs(resources) do
    local item = getItemWithQty(items, res, res.ignoreDamage)
    if not item then
      item = {
        damage = res.damage,
        nbtHash = res.nbtHash,
        name = res.name,
        displayName = getName(res),
        count = 0
      }
    end

    if res.limit and item.count > res.limit then
      chestAdapter:provide(res, item.count - res.limit, nil, config.trashDirection)

    elseif res.low and item.count < res.low then
      if res.ignoreDamage then
        item.damage = 0
      end
      local key = uniqueKey(res)
      craftList[key] = {
        damage = item.damage,
        nbtHash = item.nbtHash,
        count = res.low - item.count,
        name = item.name,
        displayName = item.displayName,
        status = '',
        rsControl = res.rsControl,
      }
    end

    if res.rsControl and res.rsDevice and res.rsSide then
      pcall(function() 
        device[res.rsDevice].setOutput(res.rsSide, item.count < res.low)
      end)
    end
  end

  return craftList
end

local itemPage = UI.Page {
  backgroundColor = colors.lightGray,
  titleBar = UI.TitleBar {
    title = 'Limit Resource',
    previousPage = true,
    event = 'form_cancel',
    backgroundColor = colors.green
  },
  displayName = UI.Window {
    x = 2, y = 2, width = UI.term.width - 4, height = 3,
  },
  form = UI.Form {
    x = 4, y = 5, height = 8, rex = -4,
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
        { name = 'Yes', value = true },
        { name = 'No', value = false },
      },
      help = 'Craft until out of ingredients'
    },
    [4] = UI.Chooser {
      width = 7,
      formLabel = 'Ignore Dmg', formKey = 'ignore_dmg',
      nochoice = 'No',
      choices = {
        { name = 'Yes', value = true },
        { name = 'No', value = false },
      },
      help = 'Ignore damage of item'
    },
    [5] = UI.Chooser {
      width = 7,
      formLabel = 'RS Control', formKey = 'rsControl',
      nochoice = 'No',
      choices = {
        { name = 'Yes', value = true },
        { name = 'No', value = false },
      },
      help = 'Control via redstone'
    },
    [6] = UI.Chooser {
      width = 25,
      formLabel = 'RS Device', formKey = 'rsDevice',
      --choices = devices,
      help = 'Redstone Device'
    },
    [7] = UI.Chooser {
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
    str = str .. string.format('\n%s', item.nbtHash)
  end
  self:setCursorPos(1, 1)
  self:print(str)
end

function itemPage:enable(item)
  self.item = item

  self.form:setValues(item)
  self.titleBar.title = item.name

  local devices = self.form[6].choices
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
    local keys = { 'name', 'auto', 'low', 'limit', 'damage',
                   'nbtHash', 'ignoreDamage',
                   'rsControl', 'rsDevice', 'rsSide', }

    local filtered = { }
    for _,key in pairs(keys) do
      filtered[key] = values[key]
    end
    filtered.low = tonumber(filtered.low)
    filtered.limit = tonumber(filtered.limit)

    --filtered.ignoreDamage = filtered.ignoreDamage == true
    --filtered.auto = filtered.auto == true
    --filtered.rsControl = filtered.rsControl == true

    if filtered.auto ~= true then
      filtered.auto = nil
    end
 
    if filtered.rsControl ~= true then
      filtered.rsControl = nil
      filtered.rsSide = nil
      filtered.rsDevice = nil
    end

    if values.ignoreDamage == true then
      filtered.damage = 0
    end

    resources[uniqueKey(filtered)] = filtered
    Util.writeTable(RESOURCE_FILE, resources)

    UI:setPreviousPage()

  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

local listingPage = UI.Page {
  menuBar = UI.MenuBar {
    buttons = {
      { text = 'Learn',  event = 'learn'  },
      { text = 'Forget', event = 'forget' },
      { text = 'Craft',  event = 'craft'  },
    },
  },
  grid = UI.Grid {
    y = 2, height = UI.term.height - 2,
    columns = {
      { heading = 'Name', key = 'displayName' , width = 22 },
      { heading = 'Qty',  key = 'count'       , width = 5  },
      { heading = 'Min',  key = 'low'         , width = 4  },
      { heading = 'Max',  key = 'limit'       , width = 4  },
    },
    sortColumn = 'displayName',
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
    UI:exitPullEvents()

  elseif event.type == 'grid_select' then
    local selected = event.selected
    UI:setPage('item', selected)

  elseif event.type == 'refresh' then
    self:refresh()
    self.grid:draw()
    self.statusBar.filter:focus()

  elseif event.type == 'learn' then
    UI:setPage('learn')

  elseif event.type == 'craft' then
    UI:setPage('craft')

  elseif event.type == 'forget' then
    local item = self.grid:getSelected()
    if item then
      local key = uniqueKey(item)

      if recipes[key] then
        recipes[key] = nil
        Util.writeTable(RECIPES_FILE, recipes)
      end

      if resources[key] then
        resources[key] = nil
        Util.writeTable(RESOURCE_FILE, resources)
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
  self.allItems = chestAdapter:listItems()
  mergeResources(self.allItems)
  self:applyFilter()
end

function listingPage:applyFilter()
  local t = filterItems(self.allItems, self.filter)
  self.grid:setValues(t)
end

-- without duck antenna
local function getTurtleInventoryOld()
  local inventory = { }
  for i = 1,16 do
    if turtle.getItemCount(i) > 0 then
      turtle.select(i)
      local item = turtle.getItemDetail()
      inventory[i] = {
        name = item.name,
        damage = item.damage,
        count = item.count,
      }
    end
  end
  return inventory
end

local function getTurtleInventory()
  local inventory = { }
  for i = 1,16 do
    local qty = turtle.getItemCount(i)
    if qty > 0 then
      turtleChestAdapter:insert(i, qty)
      local items = turtleChestAdapter:listItems()
      _, inventory[i] = next(items)
      turtleChestAdapter:extract(1, qty, i)
    end
  end
  return inventory
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
  local recipe = { }
  local ingredients = getTurtleInventory()
  if ingredients then
    turtle.select(1)
    if device.workbench and turtle.craft() then
      recipe = getTurtleInventory()
      if recipe and recipe[1] then
        clearGrid()

        local key = uniqueKey(recipe[1])
        local newRecipe = {
          count = recipe[1].count,
          ingredients = ingredients,
        }
        if recipe[1].maxCount ~= 64 then
          newRecipe.maxCount = recipe[1].maxCount
        end

        for k,ingredient in pairs(ingredients) do
          ingredients[k] = uniqueKey(ingredient)
        end

        recipes[key] = newRecipe

        Util.writeTable(RECIPES_FILE, recipes)

        local displayName = getName(recipe[1])

        listingPage.statusBar.filter:setValue(displayName)
        listingPage.statusBar:timedStatus('Learned: ' .. displayName, 3)
        listingPage.filter = displayName
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

local learnPage = UI.Dialog {
  height = 7, width = UI.term.width - 6,
  backgroundColor = colors.lightGray,
  title = 'Learn Recipe',
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

function learnPage:enable()
  craftingPaused = true
  self:focusFirst()
  UI.Dialog.enable(self)
end

function learnPage:disable()
  craftingPaused = false
  UI.Dialog.disable(self)
end
 
function learnPage:eventHandler(event)
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

local craftPage = UI.Dialog {
  height = 6, width = UI.term.width - 10,
  backgroundColor = colors.lightGray,
  title = 'Enter amount to craft',
  idField = UI.TextEntry {
    x = 15,
    y = 3,
    width = 10,
    limit = 6,
    value = '1',
    backgroundColor = colors.black,
    backgroundFocusColor = colors.black,
  },
  accept = UI.Button {
    rx = -7, ry = -1,
    backgroundColor = colors.green,
    text = '+', event = 'accept',
  },
  cancel = UI.Button {
    rx = -3, ry = -1,
    backgroundColor = colors.red,
    backgroundFocusColor = colors.red,
    text = '\215', event = 'cancel'
  },
}

function craftPage:draw()
  UI.Dialog.draw(self)
  self:write(6, 3, 'Quantity')
end

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
    
  else
    return UI.Dialog.eventHandler(self, event)
  end
  return true
end

UI:setPages({
  listing = listingPage,
  item = itemPage,
  learn = learnPage,
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
    local items = chestAdapter:listItems()
    if Util.size(items) == 0 then
      jobListGrid.parent:clear()
      jobListGrid.parent:centeredWrite(math.ceil(jobListGrid.parent.height/2), 'No items in system')
      jobListGrid:sync()

    else
      local craftList = watchResources(items)
      jobListGrid:setValues(craftList)
      --jobListGrid:draw()
      --jobListGrid:sync()
      craftItems(craftList, items)
      jobListGrid:update()
      jobListGrid:draw()
      jobListGrid:sync()
      craftList = getAutocraftItems(items) -- autocrafted items don't show on job monitor
      craftItems(craftList, items)
    end
  end
end)

UI:pullEvents()
jobListGrid.parent:reset()

local class      = require('class')
local Util       = require('util')
local Peripheral = require('peripheral')

local MEProvider = class()

function MEProvider:init(args)
  local defaults = {
    items = { },
    name = 'ME',
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  if self.side then
    local mep = peripheral.wrap('bottom')
    if mep then
      Util.merge(self, mep)
    end
  else
    local mep = Peripheral.getByMethod('getAvailableItems')
    if mep then
      Util.merge(self, mep)
    end
  end

  local sides = {
    top = 'down',
    bottom = 'up',
    east = 'west',
    west = 'east',
    north = 'south',
    south = 'north',
  }
  self.oside = sides[self.direction or self.side]
end
 
function MEProvider:isValid()
  return self.getAvailableItems and self.getAvailableItems()
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

local convertNames = {
  name = 'id',
  damage = 'dmg',
  maxCount = 'max_size',
  count = 'qty',
  displayName = 'display_name',
  maxDamage = 'max_dmg',
}

local function convertItem(item)
  for k,v in pairs(convertNames) do
    item[k] = item[v]
    item[v] = nil
  end
  item.displayName = safeString(item.displayName)
end

function MEProvider:refresh()
  self.items = self.getAvailableItems('all')
  for _,v in pairs(self.items) do
    Util.merge(v, v.item)
    convertItem(v)
  end
  return self.items
end

function MEProvider:listItems()
  self:refresh()
  return self.items
end
 
function MEProvider:getItemInfo(name, damage)
 
  for key,item in pairs(self.items) do
    if item.name == name and item.damage == damage then
      return item
    end
  end
end
 
function MEProvider:craft(name, damage, count)

  self:refresh()

  local item = self:getItemInfo(name, damage)

  if item and item.is_craftable then

    self.requestCrafting({ id = name, dmg = damage }, count)
    return true
  end
end

function MEProvider:craftItems(items)
  local cpus = self.getCraftingCPUs() or { }
  local count = 0

  for _,cpu in pairs(cpus) do
    if cpu.busy then
      return
    end
  end

  for _,item in pairs(items) do
    if count >= #cpus then
      break
    end
    if self:craft(item.name, item.damage, item.count) then
      count = count + 1
    end
  end
end

function MEProvider:provide(item, count, slot)
  return pcall(function()
    self.exportItem({
      id = item.name,
      dmg = item.damage
    }, self.oside, count, slot)
  end)
end
 
function MEProvider:insert(slot, count)
  local s, m = pcall(function() self.pullItem(self.oside, slot, count) end)
  if not s and m then
    print('MEProvider:pullItem')
    print(m)
    sleep(1)
    s, m = pcall(function() self.pullItem(self.oside, slot, count) end)
    if not s and m then
      print('MEProvider:pullItem')
      print(m)
      read()
    end
  end
end

return MEProvider

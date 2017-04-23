local class = require('class')
local Peripheral = require('peripheral')
local TableDB = require('tableDB')

local RefinedProvider = class()

local keys = { 
  'fields',
  'damage',
  'displayName',
  'maxCount',
  'maxDamage',
  'name',
  'nbtHash',
  'rawName',
}

function RefinedProvider:init(args)
  
  local defaults = {
    items = { },
    name = 'refinedStorage',
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  local controller = Peripheral.getByType('refinedstorage:controller')
  if controller then
    Util.merge(self, controller)
  end

  if not self.itemInfoDB then
    self.itemInfoDB = TableDB({
      fileName = 'items.db'
    })

    self.itemInfoDB:load()
  end
end
 
function RefinedProvider:isValid()
  return not not self.listAvailableItems
end

function RefinedProvider:isOnline()
  return self.getNetworkEnergyStored() > 0
end

function RefinedProvider:getCachedItemDetails(item)
  local key = table.concat({ item.name, item.damage, item.nbtHash }, ':')

  local detail = self.itemInfoDB:get(key)
  if not detail then
    detail = self.findItem(item)
    if detail then
      local meta
      pcall(function() meta = detail.getMetadata() end)
      if not meta then
        return
      end
      Util.merge(detail, meta)
      if detail.maxDamage and detail.maxDamage > 0 and detail.damage > 0 then
        detail.displayName = detail.displayName .. ' (damaged)'
      end
      detail.lname = detail.displayName:lower()

      -- backwards capability
      detail.dmg = detail.damage
      detail.id = detail.name
      detail.qty = detail.count
      detail.display_name = detail.displayName
      detail.nbtHash = item.nbtHash

      local t = { }
      for _,key in pairs(keys) do
        t[key] = detail[key]
      end

      detail = t
      self.itemInfoDB:add(key, detail)
    end
  end
  if detail then
    return Util.shallowCopy(detail)
  end
end

function RefinedProvider:listItems()
  local items = { }
  local list

  pcall(function()
    list = self.listAvailableItems()
  end)

  if list then
    for _,v in pairs(list) do
      local item = self:getCachedItemDetails(v)
      if item then
        item.count = v.count
        item.qty = v.count
        table.insert(items, item)
      end
    end
    self.itemInfoDB:flush()
  end

  return items
end

function RefinedProvider:getItemInfo(fingerprint)

  local key = table.concat({ fingerprint.name, fingerprint.damage, fingerprint.nbtHash }, ':')

  local item = self.itemInfoDB:get(key)
  if not item then
    return self:getCachedItemDetails(fingerprint)
  end

  local detail = self.findItem(item)
  if detail then
    item.count = detail.count
    item.qty = detail.count
    return item
  end
end

function RefinedProvider:isCrafting(item)
  for _,task in pairs(self.getCraftingTasks()) do
    local output = task.getPattern().outputs[1]
    if output.name == item.name and 
       output.damage == item.damage and 
       output.nbtHash == item.nbtHash then
      return true
    end
  end
  return false
end

function RefinedProvider:craft(item, qty)
  local detail = self.findItem(item)
  if detail then
    return detail.craft(qty)
  end
end

function RefinedProvider:craftItems(items)
  return false
end

function RefinedProvider:provide(item, qty, slot)
end
 
function RefinedProvider:extract(slot, qty)
--  self.pushItems(self.direction, slot, qty)
end

function RefinedProvider:insert(slot, qty)
--  self.pullItems(self.direction, slot, qty)
end

return RefinedProvider

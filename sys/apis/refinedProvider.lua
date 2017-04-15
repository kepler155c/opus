local class = require('class')
local Peripheral = require('peripheral')

local RefinedProvider = class()
 
function RefinedProvider:init(args)
  
  local defaults = {
    cache = { },
    items = { },
    name = 'refinedStorage',
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  self.controller = Peripheral.getByType('refinedstorage:controller')
end
 
function RefinedProvider:isValid()
  return not not self.controller
end

function RefinedProvider:getCachedItemDetails(item)
  local key = table.concat({ item.name, item.damage, item.nbtHash }, ':')

  local detail = self.cache[key]
  if not detail then
    detail = self.controller.findItem(item)
    if detail then
      Util.merge(detail, detail.getMetadata())
      if detail.displayName then
        if detail.maxDamage and detail.maxDamage > 0 and detail.damage > 0 then
          detail.displayName = detail.displayName .. ' (damaged)'
        end
        detail.lname = detail.displayName:lower()

        -- backwards capability
        detail.dmg = detail.damage
        detail.id = detail.name
        detail.qty = detail.count
        detail.display_name = detail.displayName

        self.cache[key] = detail
      end
    end
  end
  return detail
end

function RefinedProvider:listItems()
  local items = { }
  local list

  pcall(function()
    list = self.controller.listAvailableItems()
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
  end

  return items
end

function RefinedProvider:getItemInfo(fingerprint)

  local key = table.concat({ fingerprint.name, fingerprint.damage, fingerprint.nbtHash }, ':')

  local item = self.cache[key]
  if not item then
    return self:getCachedItemDetails(fingerprint)
  end

  local detail = self.controller.findItem(item)
  if detail then
    item.count = detail.count
    item.qty = detail.count
    return item
  end
end
 
function RefinedProvider:craft(id, dmg, qty)
  return false
end

function RefinedProvider:craftItems(items)
  return false
end

function RefinedProvider:provide(item, qty, slot)
end
 
function RefinedProvider:extract(slot, qty)
--  self.controller.pushItems(self.direction, slot, qty)
end

function RefinedProvider:insert(slot, qty)
--  self.controller.pullItems(self.direction, slot, qty)
end

return RefinedProvider

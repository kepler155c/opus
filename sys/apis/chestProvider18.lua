local class = require('class')
local itemDB = require('itemDB')
local Peripheral = require('peripheral')

local ChestProvider = class()

local keys = Util.transpose({ 
  'damage',
  'displayName',
  'maxCount',
  'maxDamage',
  'name',
  'nbtHash',
})

function ChestProvider:init(args)
  local defaults = {
    items = { },
    name = 'chest',
    direction = 'up',
    wrapSide = 'bottom',
  }
  Util.merge(self, defaults)
  Util.merge(self, args)
  
  local chest = Peripheral.getBySide(self.wrapSide)
  if not chest then
    chest = Peripheral.getByMethod('list')
  end
  if chest then
    Util.merge(self, chest)
  end
end

function ChestProvider:isValid()
  return not not self.list
end

function ChestProvider:getCachedItemDetails(item, k)
  local key = { item.name, item.damage, item.nbtHash }

  local detail = itemDB:get(key)
  if not detail then
    pcall(function() detail = self.getItemMeta(k) end)
    if not detail then
      return
    end
-- NOT SUFFICIENT
    if detail.name ~= item.name then
      return
    end

    for _,k in ipairs(Util.keys(detail)) do
      if not keys[k] then
        detail[k] = nil
      end
    end

    itemDB:add(key, detail)
  end
  if detail then
    return Util.shallowCopy(detail)
  end
end

function ChestProvider:refresh(throttle)
  return self:listItems(throttle)
end

-- provide a consolidated list of items
function ChestProvider:listItems(throttle)
  self.cache = { }
  local items = { }

  throttle = throttle or Util.throttle()

  for k,v in pairs(self.list()) do
    local key = table.concat({ v.name, v.damage, v.nbtHash }, ':')

    local entry = self.cache[key]
    if not entry then
      entry = self:getCachedItemDetails(v, k)
      if entry then
        entry.dmg = entry.damage
        entry.id = entry.name
        entry.count = 0
        entry.display_name = entry.displayName
        entry.max_size = entry.maxCount
        entry.nbt_hash = entry.nbtHash
        entry.lname = entry.displayName:lower()
        self.cache[key] = entry
        table.insert(items, entry)
      end
    end

    if entry then
      entry.count = entry.count + v.count
      entry.qty = entry.count
    end
    throttle()
  end

  itemDB:flush()

  return items
end

function ChestProvider:getItemInfo(id, dmg, nbtHash)
  if not self.cache then
    self:listItems()
  end
  local key = table.concat({ id, dmg, nbtHash }, ':')
  return self.cache[key]
end

function ChestProvider:craft(id, dmg, qty)
end

function ChestProvider:craftItems(items)
end

function ChestProvider:provide(item, qty, slot, direction)
  local stacks = self.list()
  for key,stack in pairs(stacks) do
    if stack.name == item.id and stack.damage == item.dmg then
      local amount = math.min(qty, stack.count)
      if amount > 0 then
        self.pushItems(direction or self.direction, key, amount, slot)
      end
      qty = qty - amount
      if qty <= 0 then
        break
      end
    end
  end
end

function ChestProvider:extract(slot, qty, toSlot)
  self.pushItems(self.direction, slot, qty, toSlot)
end

function ChestProvider:insert(slot, qty)
  self.pullItems(self.direction, slot, qty)
end

return ChestProvider

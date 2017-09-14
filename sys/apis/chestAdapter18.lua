local class      = require('class')
local Util       = require('util')
local itemDB     = require('itemDB')
local Peripheral = require('peripheral')

local ChestAdapter = class()

local keys = Util.transpose({ 
  'damage',
  'displayName',
  'maxCount',
  'maxDamage',
  'name',
  'nbtHash',
})

function ChestAdapter:init(args)
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

function ChestAdapter:isValid()
  return not not self.list
end

function ChestAdapter:getCachedItemDetails(item, k)
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

function ChestAdapter:refresh(throttle)
  return self:listItems(throttle)
end

-- provide a consolidated list of items
function ChestAdapter:listItems(throttle)
  self.cache = { }
  local items = { }

  throttle = throttle or Util.throttle()

  for k,v in pairs(self.list()) do
    local key = table.concat({ v.name, v.damage, v.nbtHash }, ':')

    local entry = self.cache[key]
    if not entry then
      entry = self:getCachedItemDetails(v, k)
      if entry then
        entry.count = 0
        self.cache[key] = entry
        table.insert(items, entry)
      end
    end

    if entry then
      entry.count = entry.count + v.count
    end
    throttle()
  end

  itemDB:flush()

  return items
end

function ChestAdapter:getItemInfo(name, damage, nbtHash)
  if not self.cache then
    self:listItems()
  end
  local key = table.concat({ name, damage, nbtHash }, ':')
  return self.cache[key]
end

function ChestAdapter:craft(name, damage, qty)
end

function ChestAdapter:craftItems(items)
end

function ChestAdapter:provide(item, qty, slot, direction)
  local stacks = self.list()
  for key,stack in pairs(stacks) do
    if stack.name == item.name and stack.damage == item.damage then
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

function ChestAdapter:extract(slot, qty, toSlot)
  self.pushItems(self.direction, slot, qty, toSlot)
end

function ChestAdapter:insert(slot, qty)
  self.pullItems(self.direction, slot, qty)
end

return ChestAdapter

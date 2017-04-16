local class = require('class')

local ChestProvider = class()
 
function ChestProvider:init(args)
  
  args = args or { }

  self.items = { }  -- consolidated item info
  self.stacks = { } -- raw stack info
  self.name = 'chest'
  self.direction = args.direction or 'up'
  self.wrapSide = args.wrapSide or 'bottom'
  self.p = peripheral.wrap(self.wrapSide)
end
 
function ChestProvider:isValid()
  return self.p and self.p.list
end
 
function ChestProvider:refresh()
  if self.p then
    --self.p.condenseItems()
    self.items = { }
    self.stacks = self.p.list()
    for k,s in pairs(self.stacks) do

      local key = s.name .. ':' .. s.damage
      local entry = self.items[key]
      if not entry then
        local meta = self.p.getItemMeta(k)
        entry = {
          id = s.name,
          dmg = s.damage,
          name = meta.displayName,
          max_size = meta.maxCount,
          qty = 0,
        }
        self.items[key] = entry
      end
      entry.qty = entry.qty + s.count
    end
  end
  return self.items
end

function ChestProvider:getItemInfo(id, dmg)
 
  for key,item in pairs(self.items) do
    if item.id == id and item.dmg == dmg then
      return item
    end
  end
end
 
function ChestProvider:craft(id, dmg, qty)
  return false
end

function ChestProvider:craftItems(items)
end

function ChestProvider:provide(item, qty, slot)
  if self.p then
    self:refresh()
    for key,stack in pairs(self.stacks) do
      if stack.name == item.id and stack.damage == item.dmg then
        local amount = math.min(qty, stack.count)
        self.p.pushItems(self.direction, key, amount, slot)
        qty = qty - amount
        if qty <= 0 then
          break
        end
      end
    end
  end
end
 
function ChestProvider:extract(slot, qty)
  if self.p then
    self.p.pushItems(self.direction, slot, qty)
  end
end

function ChestProvider:insert(slot, qty)
  if self.p then
    self.p.pullItems(self.direction, slot, qty)
  end
end

return ChestProvider

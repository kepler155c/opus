local class = require('class')

local ChestProvider = class()
 
function ChestProvider:init(args)
  
  args = args or { }

  self.items = { }  -- consolidated item info
  self.cache = { }
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
    self.items = { }
    for k,s in pairs(self.p.list()) do

      local key = s.name .. ':' .. s.damage
      local entry = self.items[key]
      if not entry then
        entry = self.cache[key]
        if not entry then
          local meta = self.p.getItemMeta(k) -- slow method.. cache for speed
          entry = {
            id = s.name,
            dmg = s.damage,
            name = meta.displayName,
            max_size = meta.maxCount,
          }
          self.cache[key] = entry
        end
        entry = Util.shallowCopy(entry)
        self.items[key] = entry
        entry.qty = 0
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
end

function ChestProvider:craftItems(items)
end

function ChestProvider:provide(item, qty, slot)
  if self.p then
    local stacks = self.p.list()
    for key,stack in pairs(stacks) do
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

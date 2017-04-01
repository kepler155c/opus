local class = require('class')
local Logger = require('logger')

local ChestProvider = class()
 
function ChestProvider:init(args)
  
  args = args or { }

  self.stacks = {}
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
    self.stacks = self.p.list()
    local t = { }
    for _,s in pairs(self.stacks) do
      s.id = s.name
      s.dmg = s.damage
      s.qty = s.count
      local key = s.id .. ':' .. s.dmg
      if t[key] and t[key].qty < 64 then
        t[key].max_size = t[key].qty
      else
        t[key] = {
          qty = s.qty
        }
      end
    end
    for _,s in ipairs(self.stacks) do
      local key = s.id .. ':' .. s.dmg
      if t[key].max_size then
        s.max_size = t[key].qty
      else
        s.max_size = 64
      end
    end
  end
  return self.stacks
end
 
function ChestProvider:getItemInfo(id, dmg)
  local item = { id = id, dmg = dmg, qty = 0, max_size = 64 }
  for k,stack in pairs(self.stacks) do
    if stack.id == id and stack.dmg == dmg then
      local meta = self.p.getItemMeta(k)
      if meta then
        item.name = meta.displayName
        item.qty = item.qty + meta.count
        item.max_size = meta.maxCount
      end
    end
  end
  if item.name then
    return item
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
      if stack.id == item.id and stack.dmg == item.dmg then
        local amount = math.min(qty, stack.qty)
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

local Util    = require('util')
local TableDB = require('tableDB')

local itemDB = TableDB({ fileName = 'usr/etc/items.db' })

function itemDB:get(key)

  local item = TableDB.get(self, key)

  if item then
    return item
  end

  if key[2] ~= 0 then
    item = TableDB.get(self, { key[1], 0, key[3] })
    if item and item.maxDamage > 0 then
      item = Util.shallowCopy(item)
      item.damage = key[2]
      item.displayName = string.format('%s (damage: %d)', item.displayName, item.damage)
      return item
    end
  end
end

function itemDB:add(key, item)

  if item.maxDamage > 0 then
    key = { key[1], 0, key[3] }
  end
  TableDB.add(self, key, item)
end

function itemDB:makeKey(item)
  return { item.name, item.damage, item.nbtHash }
end

itemDB:load()

return itemDB

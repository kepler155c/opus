requireInjector(getfenv(1))

local RefinedProvider = require('refinedProvider')
local TableDB         = require('tableDB')

local controller = RefinedProvider()
if not controller:isValid() then
  error('Refined storage controller not found')
end

local itemInfoDB = TableDB({
  fileName = 'items.db'
})

itemInfoDB:load()

local items = controller:listItems()

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

for _, item in pairs(items) do

  local t = { }
  for _,key in pairs(keys) do
    t[key] = item[key]
  end

  itemInfoDB:add({ item.name, item.damage, item.nbtHash }, t)
end

itemInfoDB:flush()

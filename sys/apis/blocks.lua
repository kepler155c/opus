local class = require('class')
local TableDB = require('tableDB')
local JSON = require('json')

-- see https://github.com/Khroki/MCEdit-Unified/blob/master/pymclevel/minecraft.yaml
-- see https://github.com/Khroki/MCEdit-Unified/blob/master/Items/minecraft/blocks.json

--[[-- nameDB --]]--
local nameDB = TableDB({
  fileName = 'blocknames.db'
})
function nameDB:load(dir, blockDB)
  self.fileName = fs.combine(dir, self.fileName)
  if fs.exists(self.fileName) then
    TableDB.load(self)
  end
  self.blockDB = blockDB
end

function nameDB:getName(id, dmg)
  return self:lookupName(id, dmg) or id .. ':' .. dmg
end
 
function nameDB:lookupName(id, dmg)
  -- is it in the name db ?
  local name = self:get({ id, dmg })
  if name then
    return name
  end

  -- is it in the block db ?
  for _,v in pairs(self.blockDB.data) do
    if v.strId == id and v.dmg == dmg then
      return v.name
    end
  end
end

--[[-- blockDB --]]--
local blockDB = TableDB()

function blockDB:load()

  local blocks = JSON.decodeFromFile(fs.combine('sys/etc', 'blocks.json'))

  if not blocks then
    error('Unable to read blocks.json')
  end

  for strId, block in pairs(blocks) do
    strId = 'minecraft:' .. strId
    if type(block.name) == 'string' then
      self:add(block.id, 0, block.name, strId, block.place)
    else
      for nid,name in pairs(block.name) do
        self:add(block.id, nid - 1, name, strId, block.place)
      end
    end
  end
end

function blockDB:lookup(id, dmg)
  if not id then
    return
  end
 
  return self.data[id .. ':' .. dmg]
end

function blockDB:add(id, dmg, name, strId, place)
  local key = id .. ':' .. dmg

  TableDB.add(self, key, {
    id = id,
    dmg = dmg,
    name = name,
    strId = strId,
    place = place,
  })
end

--[[-- placementDB --]]--
-- in memory table that expands the standardBlock and blockType tables for each item/dmg/placement combination
local placementDB = TableDB()

function placementDB:load(sbDB, btDB)

  for k,blockType in pairs(sbDB.data) do
    local bt = btDB.data[blockType]
    if not bt then
      error('missing block type: ' .. blockType)
    end
    local id, dmg = string.match(k, '(%d+):*(%d+)')
    self:addSubsForBlockType(tonumber(id), tonumber(dmg), bt)
  end
end

function placementDB:load2(sbDB, btDB)

  for k,v in pairs(sbDB.data) do
    if v.place then
      local bt = btDB.data[v.place]
      if not bt then
        error('missing block type: ' .. v.place)
      end
      local id, dmg = string.match(k, '(%d+):*(%d+)')
      self:addSubsForBlockType(tonumber(id), tonumber(dmg), bt)
    end
  end

  -- special case for quartz pillars
  self:addSubsForBlockType(155, 2, btDB.data['quartz-pillar'])
end


function placementDB:addSubsForBlockType(id, dmg, bt)
  for _,sub in pairs(bt) do
    local odmg = sub.odmg
    if type(sub.odmg) == 'string' then
      odmg = dmg + tonumber(string.match(odmg, '+(%d+)'))
    end

    local b = blockDB:lookup(id, dmg)
    local strId = tostring(id)
    if b then
      strId = b.strId
    end

    self:add(
      id,
      odmg,
      sub.sid or strId,
      sub.sdmg or dmg,
      sub.dir,
      sub.extra)
  end
end
 
function placementDB:add(id, dmg, sid, sdmg, direction, extra)
  if direction and #direction == 0 then
    direction = nil
  end
 
  local entry = {
    oid = id,      -- numeric ID
    odmg = dmg,    -- dmg with placement info
    id = sid,    -- string ID
    dmg = sdmg,  -- dmg without placement info
    direction = direction,
  }
  if extra then
    Util.merge(entry, extra)
  end

  self.data[id .. ':' .. dmg] = entry
end

--[[-- BlockTypeDB --]]--
local blockTypeDB = TableDB()

function blockTypeDB:addTemp(blockType, subs)
  local bt = self.data[blockType]
  if not bt then
    bt = { }
    self.data[blockType] = bt
  end
  for _,sub in pairs(subs) do
    table.insert(bt, {
      odmg = sub[1],
      sid = sub[2],
      sdmg = sub[3],
      dir = sub[4],
      extra = sub[5]
    })
  end
  self.dirty = true
end
 
function blockTypeDB:load()
 
  blockTypeDB:addTemp('stairs', {
    { 0, nil, 0, 'east-up' },
    { 1, nil, 0, 'west-up' },
    { 2, nil, 0, 'south-up' },
    { 3, nil, 0, 'north-up' },
    { 4, nil, 0, 'east-down' },
    { 5, nil, 0, 'west-down' },
    { 6, nil, 0, 'south-down' },
    { 7, nil, 0, 'north-down' },
  })
  blockTypeDB:addTemp('gate', {
    {  0, nil, 0, 'north' },
    {  1, nil, 0, 'east' },
    {  2, nil, 0, 'south' },
    {  3, nil, 0, 'west' },
    {  4, nil, 0, 'north' },
    {  5, nil, 0, 'east' },
    {  6, nil, 0, 'south' },
    {  7, nil, 0, 'west' },
  })
  blockTypeDB:addTemp('pumpkin', {
    {  0, nil, 0, 'north-block' },
    {  1, nil, 0, 'east-block' },
    {  2, nil, 0, 'south-block' },
    {  3, nil, 0, 'west-block' },
    {  4, nil, 0, 'north-block' },
    {  5, nil, 0, 'east-block' },
    {  6, nil, 0, 'south-block' },
    {  7, nil, 0, 'west-block' },
  })
  blockTypeDB:addTemp('anvil', {
    {  0, nil, 0, 'south' },
    {  1, nil, 0, 'east' },
    {  2, nil, 0, 'south'},
    {  3, nil, 0, 'east' },
    {  4, nil, 0, 'south' },
    {  5, nil, 0, 'east' },
    {  6, nil, 0, 'east' },
    {  7, nil, 0, 'south' },
    {  8, nil, 0, 'south' },
    {  9, nil, 0, 'east' },
    {  10, nil, 0, 'east' },
    {  11, nil, 0, 'south' },
    {  12, nil, 0 },
    {  13, nil, 0 },
    {  14, nil, 0 },
    {  15, nil, 0 },
  })
  blockTypeDB:addTemp('bed', {
    {  0, nil, 0, 'south' },
    {  1, nil, 0, 'west' },
    {  2, nil, 0, 'north' },
    {  3, nil, 0, 'east' },
    {  4, nil, 0, 'south' },
    {  5, nil, 0, 'west' },
    {  6, nil, 0, 'north' },
    {  7, nil, 0, 'east' },
    {  8, 'minecraft:air', 0 },
    {  9, 'minecraft:air', 0 },
    { 10, 'minecraft:air', 0 },
    { 11, 'minecraft:air', 0 },
    { 12, 'minecraft:air', 0 },
    { 13, 'minecraft:air', 0 },
    { 14, 'minecraft:air', 0 },
    { 15, 'minecraft:air', 0 },
  })
  blockTypeDB:addTemp('comparator', {
    {  0, nil, 0, 'south' },
    {  1, nil, 0, 'west' },
    {  2, nil, 0, 'north' },
    {  3, nil, 0, 'east' },
    {  4, nil, 0, 'south' },
    {  5, nil, 0, 'west' },
    {  6, nil, 0, 'north' },
    {  7, nil, 0, 'east' },
    {  8, nil, 0, 'south' },
    {  9, nil, 0, 'west' },
    { 10, nil, 0, 'north' },
    { 11, nil, 0, 'east' },
    { 12, nil, 0, 'south' },
    { 13, nil, 0, 'west' },
    { 14, nil, 0, 'north' },
    { 15, nil, 0, 'east' },
  })
  blockTypeDB:addTemp('quartz-pillar', {
    {  2, nil, 2 },
    {  3, nil, 2, 'north-south-block' },
    {  4, nil, 2, 'east-west-block' },                 -- should be east-west-block
  })
  blockTypeDB:addTemp('hay-bale', {
    {  0, nil, 0 },
    {  4, nil, 0, 'east-west-block' },                 -- should be east-west-block
    {  8, nil, 0, 'north-south-block' },
  })
  blockTypeDB:addTemp('button', {
    {  1, nil, 0, 'west-block' },
    {  2, nil, 0, 'east-block' },
    {  3, nil, 0, 'north-block' },
    {  4, nil, 0, 'south-block' },
    {  5, nil, 0 },                       -- block top
  })
  blockTypeDB:addTemp('cauldron', {
    {  0, nil, 0 },
    {  1, nil, 0 },
    {  2, nil, 0 },
    {  3, nil, 0 },
  })
  blockTypeDB:addTemp('dispenser', {
    { 0, nil, 0, 'wrench-down' },
    { 1, nil, 0, 'wrench-up' },
    { 2, nil, 0, 'south' },
    { 3, nil, 0, 'north' },
    { 4, nil, 0, 'east' },
    { 5, nil, 0, 'west' },
    { 9, nil, 0 },
  })
  blockTypeDB:addTemp('end_rod', {
    { 0, nil, 0, 'wrench-down' },
    { 1, nil, 0, 'wrench-up' },
    { 2, nil, 0, 'south-block-flip' },
    { 3, nil, 0, 'north-block-flip' },
    { 4, nil, 0, 'east-block-flip' },
    { 5, nil, 0, 'west-block-flip' },
    { 9, nil, 0 },
  })
  blockTypeDB:addTemp('hopper', {
    { 0, nil, 0 },
    { 1, nil, 0 },
    { 2, nil, 0, 'south-block' },
    { 3, nil, 0, 'north-block' },
    { 4, nil, 0, 'east-block' },
    { 5, nil, 0, 'west-block' },
    { 8, nil, 0 },
    { 9, nil, 0 },
    { 10, nil, 0 },
    { 11, nil, 0, 'south-block' },
    { 12, nil, 0, 'north-block' },
    { 13, nil, 0, 'east-block' },
    { 14, nil, 0, 'west-block' },
  })
  blockTypeDB:addTemp('mobhead', {
    { 0, nil, 0 },
    { 1, nil, 0 },
    { 2, nil, 0, 'south-block' },
    { 3, nil, 0, 'north-block' },
    { 4, nil, 0, 'west-block' },
    { 5, nil, 0, 'east-block' },
  })
  blockTypeDB:addTemp('rail', {
    { 0, nil, 0, 'south' },
    { 1, nil, 0, 'east' },
    { 2, nil, 0, 'east' },
    { 3, nil, 0, 'east' },
    { 4, nil, 0, 'south' },
    { 5, nil, 0, 'south' },
    { 6, nil, 0, 'east' },
    { 7, nil, 0, 'south' },
    { 8, nil, 0, 'east' },
    { 9, nil, 0, 'south' },
  })
  blockTypeDB:addTemp('adp-rail', {
    { 0, nil, 0, 'south' },
    { 1, nil, 0, 'east' },
    { 2, nil, 0, 'east' },
    { 3, nil, 0, 'east' },
    { 4, nil, 0, 'south' },
    { 5, nil, 0, 'south' },
    { 8, nil, 0, 'south' },
    { 9, nil, 0, 'east' },
    { 10, nil, 0, 'east' },
    { 11, nil, 0, 'east' },
    { 12, nil, 0, 'south' },
    { 13, nil, 0, 'south' },
  })
  blockTypeDB:addTemp('signpost', {
    {  0, nil, 0, 'north' },
    {  1, nil, 0, 'north', { facing = 1 } },
    {  2, nil, 0, 'north', { facing = 2 } },
    {  3, nil, 0, 'north', { facing = 3 } },
    {  4, nil, 0, 'east' },
    {  5, nil, 0, 'east', { facing = 1 } },
    {  6, nil, 0, 'east', { facing = 2 } },
    {  7, nil, 0, 'east', { facing = 3 } },
    {  8, nil, 0, 'south' },
    {  9, nil, 0, 'south', { facing = 1 } },
    { 10, nil, 0, 'south', { facing = 2 } },
    { 11, nil, 0, 'south', { facing = 3 } },
    { 12, nil, 0, 'west' },
    { 13, nil, 0, 'west', { facing = 1 } },
    { 14, nil, 0, 'west', { facing = 2 } },
    { 15, nil, 0, 'west', { facing = 3 } },
  })
  blockTypeDB:addTemp('vine', {
    { 0, nil, 0 },
    { 1, nil, 0, 'south-block-vine' },
    { 2, nil, 0, 'west-block-vine' },
    { 3, nil, 0, 'south-block-vine' },
    { 4, nil, 0, 'north-block-vine' },
    { 5, nil, 0, 'south-block-vine' },
    { 6, nil, 0, 'north-block-vine' },
    { 7, nil, 0, 'south-block-vine' },
    { 8, nil, 0, 'east-block-vine' },
    { 9, nil, 0, 'south-block-vine' },
    { 10, nil, 0, 'east-block-vine' },
    { 11, nil, 0, 'east-block-vine' },
    { 12, nil, 0, 'east-block-vine' },
    { 13, nil, 0, 'east-block-vine' },
    { 14, nil, 0, 'east-block-vine' },
    { 15, nil, 0, 'east-block-vine' },
  })
  blockTypeDB:addTemp('torch', {
    { 0, nil, 0 },
    { 1, nil, 0, 'west-block' },
    { 2, nil, 0, 'east-block' },
    { 3, nil, 0, 'north-block' },
    { 4, nil, 0, 'south-block' },
    { 5, nil, 0 },
  })
  blockTypeDB:addTemp('tripwire', {
    { 0, nil, 0, 'north-block' },
    { 1, nil, 0, 'east-block' },
    { 2, nil, 0, 'south-block' },
    { 3, nil, 0, 'west-block' },
  })
  blockTypeDB:addTemp('trapdoor', {
    { 0, nil, 0, 'south-block' },
    { 1, nil, 0, 'north-block' },
    { 2, nil, 0, 'east-block' },
    { 3, nil, 0, 'west-block' },
    { 4, nil, 0, 'south-block' },
    { 5, nil, 0, 'north-block' },
    { 6, nil, 0, 'east-block' },
    { 7, nil, 0, 'west-block' },
    { 8, nil, 0, 'south-block' },
    { 9, nil, 0, 'north-block' },
    { 10, nil, 0, 'east-block' },
    { 11, nil, 0, 'west-block' },
    { 12, nil, 0, 'south-block' },
    { 13, nil, 0, 'north-block' },
    { 14, nil, 0, 'east-block' },
    { 15, nil, 0, 'west-block' },
  })
  blockTypeDB:addTemp('piston', {  -- piston placement is broken in 1.7 -- need to add work around
    { 0, nil, 0, 'piston-down' },
    { 1, nil, 0, 'piston-up' },
    { 2, nil, 0, 'piston-north' },
    { 3, nil, 0, 'piston-south' },
    { 4, nil, 0, 'piston-west' },
    { 5, nil, 0, 'piston-east' },
    { 8, nil, 0, 'piston-down' },
    { 9, nil, 0, 'piston-up' },
    { 10, nil, 0, 'piston-north' },
    { 11, nil, 0, 'piston-south' },
    { 12, nil, 0, 'piston-west' },
    { 13, nil, 0, 'piston-east' },
  })
  blockTypeDB:addTemp('lever', {
    { 0, nil, 0, 'up' },
    { 1, nil, 0, 'west-block' },
    { 2, nil, 0, 'east-block' },
    { 3, nil, 0, 'north-block' },
    { 4, nil, 0, 'south-block' },
    { 5, nil, 0, 'north' },
    { 6, nil, 0, 'west' },
    { 7, nil, 0, 'up' },
    { 8, nil, 0, 'up' },
    { 9, nil, 0, 'west-block' },
    { 10, nil, 0, 'east-block' },
    { 11, nil, 0, 'north-block' },
    { 12, nil, 0, 'south-block' },
    { 13, nil, 0, 'north' },
    { 14, nil, 0, 'west' },
    { 15, nil, 0, 'up' },
  })
  blockTypeDB:addTemp('wallsign-ladder', {
    { 0, nil, 0 },
    { 1, nil, 0 },
    { 2, nil, 0, 'south-block' },
    { 3, nil, 0, 'north-block' },
    { 4, nil, 0, 'east-block' },
    { 5, nil, 0, 'west-block' },
  })
  blockTypeDB:addTemp('chest-furnace', {
    { 0, nil, 0 },
    { 2, nil, 0, 'south' },
    { 3, nil, 0, 'north' },
    { 4, nil, 0, 'east' },
    { 5, nil, 0, 'west' },
  })
  blockTypeDB:addTemp('repeater', {
    {  0, nil, 0, 'north' },
    {  1, nil, 0, 'east' },
    {  2, nil, 0, 'south' },
    {  3, nil, 0, 'west' },
    {  4, nil, 0, 'north' },
    {  5, nil, 0, 'east' },
    {  6, nil, 0, 'south' },
    {  7, nil, 0, 'west' },
    {  8, nil, 0, 'north' },
    {  9, nil, 0, 'east' },
    {  10, nil, 0, 'south' },
    {  11, nil, 0, 'west' },
    {  12, nil, 0, 'north' },
    {  13, nil, 0, 'east' },
    {  14, nil, 0, 'south' },
    {  15, nil, 0, 'west' },
  })
  blockTypeDB:addTemp('flatten', {
    {  0, nil, 0 },
    {  1, nil, 0 },
    {  2, nil, 0 },
    {  3, nil, 0 },
    {  4, nil, 0 },
    {  5, nil, 0 },
    {  6, nil, 0 },
    {  7, nil, 0 },
    {  8, nil, 0 },
    {  9, nil, 0 },
    {  10, nil, 0 },
    {  11, nil, 0 },
    {  12, nil, 0 },
    {  13, nil, 0 },
    {  14, nil, 0 },
    {  15, nil, 0 },
  })
  blockTypeDB:addTemp('sapling', {
    {  '+0', nil, nil },
    {  '+8', nil, nil },
  })
  blockTypeDB:addTemp('leaves', {
    {  '+0', nil, nil },
    {  '+4', nil, nil },
    {  '+8', nil, nil },
    {  '+12', nil, nil },
  })
  blockTypeDB:addTemp('slab', {
    {  '+0', nil, nil, 'bottom' },
    {  '+8', nil, nil, 'top' },
  })
  blockTypeDB:addTemp('largeplant', {
    {  '+0', nil, nil, 'east-door', { twoHigh = true } },   -- should use a generic double tall keyword
    {  '+8', 'minecraft:air', 0 },
  })
  blockTypeDB:addTemp('wood', {
    {  '+0',  nil, nil },
    {  '+4',  nil, nil, 'east-west-block' },
    {  '+8',  nil, nil, 'north-south-block' },
    {  '+12', nil, nil },
  })
  blockTypeDB:addTemp('door', {
    {  0, nil, 0, 'east-door',  { twoHigh = true } },
    {  1, nil, 0, 'south-door', { twoHigh = true } },
    {  2, nil, 0, 'west-door',  { twoHigh = true } },
    {  3, nil, 0, 'north-door', { twoHigh = true } },
    {  4, nil, 0, 'east-door',  { twoHigh = true } },
    {  5, nil, 0, 'south-door', { twoHigh = true } },
    {  6, nil, 0, 'west-door',  { twoHigh = true } },
    {  7, nil, 0, 'north-door', { twoHigh = true } },
    {  8,'minecraft:air', 0 },
    {  9,'minecraft:air', 0 },
    { 10,'minecraft:air', 0 },
    { 11,'minecraft:air', 0 },
    { 12,'minecraft:air', 0 },
    { 13,'minecraft:air', 0 },
    { 14,'minecraft:air', 0 },
    { 15,'minecraft:air', 0 },
  })
  blockTypeDB:addTemp('cocoa', {
    { 0, nil, 0, 'south-block' },
    { 1, nil, 0, 'west-block' },
    { 2, nil, 0, 'north-block' },
    { 3, nil, 0, 'east-block' },
    { 4, nil, 0, 'south-block' },
    { 5, nil, 0, 'west-block' },
    { 6, nil, 0, 'north-block' },
    { 7, nil, 0, 'east-block' },
    { 8, nil, 0, 'south-block' },
    { 9, nil, 0, 'west-block' },
    { 10, nil, 0, 'north-block' },
    { 11, nil, 0, 'east-block' },
  })
end

local Blocks = class()
function Blocks:init(args)

  Util.merge(self, args)
  self.blockDB = blockDB
  self.nameDB = nameDB

  blockDB:load()
--  standardBlockDB:load()
  blockTypeDB:load()
  nameDB:load(self.dir, blockDB)
--  placementDB:load(standardBlockDB, blockTypeDB)
  placementDB:load2(blockDB, blockTypeDB)

--  _G._b = blockDB
--  _G._s = standardBlockDB
--  _G._bt = blockTypeDB
--  _G._p = placementDB

--  Util.writeTable('pb1.lua', placementDB.data)

--  placementDB.data = { }

--  Util.writeTable('pb2.lua', placementDB.data)
end

-- for an ID / dmg (with placement info) - return the correct block (without the placment info embedded in the dmg)
function Blocks:getPlaceableBlock(id, dmg)

  local p = placementDB:get({id, dmg})
  if p then
    return Util.shallowCopy(p)
  end

  local b = blockDB:get({id, dmg})
  if b then
    return { id = b.strId, dmg = b.dmg }
  end

  b = blockDB:get({id, 0})
  if b then
    return { id = b.strId, dmg = b.dmg }
  end

  return { id = id, dmg = dmg }
end

return Blocks

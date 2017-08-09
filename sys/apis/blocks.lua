local class = require('class')
local TableDB = require('tableDB')
local JSON = require('json')

-- see https://github.com/Khroki/MCEdit-Unified/blob/master/pymclevel/minecraft.yaml
-- see https://github.com/Khroki/MCEdit-Unified/blob/master/Items/minecraft/blocks.json

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

local blockDB = TableDB({
  fileName = 'block.db',
  tabledef = {
    autokeys = false,
    columns = {
      { name = 'key',     type = 'key',    length = 8 },
      { name = 'id',      type = 'number', length = 5 },
      { name = 'dmg',     type = 'number', length = 2 },
      { name = 'name',    type = 'string', length = 35 },
      { name = 'refname', type = 'string', length = 35 },
      { name = 'strId',   type = 'string', length = 80 },
    }
  }
})

function blockDB:load(dir)
  self.fileName = fs.combine(dir, self.fileName)
  if fs.exists(self.fileName) then
    TableDB.load(self)
  else
    self:seedDB(dir)
  end
end
 
function blockDB:seedDB(dir)

  local blocks = JSON.decodeFromFile(fs.combine('sys/etc', 'blocks.json'))

  if not blocks then
    error('Unable to read blocks.json')
  end

  for strId, block in pairs(blocks) do
    strId = 'minecraft:' .. strId
    if type(block.name) == 'string' then
      self:add(block.id, 0, block.name, strId)
    else
      for nid,name in pairs(block.name) do
        self:add(block.id, nid - 1, name, strId)
      end
    end
  end
 
  self.dirty = true
  -- self:flush()
end
 
function blockDB:lookup(id, dmg)

  if not id then
    return
  end
  if not id or not dmg then error('blockDB:lookup: nil passed', 2) end
  local key = id .. ':' .. dmg
 
  return self.data[key]
end

function blockDB:add(id, dmg, name, strId)
  local key = id .. ':' .. dmg
 
  TableDB.add(self, key, {
    id = id,
    dmg = dmg,
    key = key,
    name = name,
    strId = strId,
  })
end

--[[-- placementDB --]]--
-- in memory table that expands the standardBlock and blockType tables for each item/dmg/placement combination
local placementDB = TableDB({
  fileName = 'placement.db'
})

function placementDB:load(dir, sbDB, btDB)

  self.fileName = fs.combine(dir, self.fileName)

  for k,blockType in pairs(sbDB.data) do
    local bt = btDB.data[blockType]
    if not bt then
      error('missing block type: ' .. blockType)
    end
    local id, dmg = string.match(k, '(%d+):*(%d+)')
    self:addSubsForBlockType(tonumber(id), tonumber(dmg), bt)
  end

-- testing
  self.dirty = true
  --self:flush()
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
  if not id or not dmg then error('placementDB:add: nil passed', 2) end
 
  local key = id .. ':' .. dmg
 
  if direction and #direction == 0 then
    direction = nil
  end
 
  self.data[key] = {
    id = id,      -- numeric ID
    dmg = dmg,    -- dmg with placement info
    key = key,
    sid = sid,    -- string ID
    sdmg = sdmg,  -- dmg without placement info
    direction = direction,
    extra = extra,
  }
end

--[[-- StandardBlockDB --]]--
local standardBlockDB = TableDB({
  fileName = 'standard.db',
  tabledef = {
    autokeys = false,
    type = 'simple',
    columns = {
      { label = 'Key', type = 'key', length = 8 },
      { label = 'Block Type', type = 'string', length = 20 }
    }
  }
})
 
function standardBlockDB:load(dir)
  self.fileName = fs.combine(dir, self.fileName)

  if fs.exists(self.fileName) then
    TableDB.load(self)
  else
    self:seedDB()
  end
end
 
function standardBlockDB:seedDB()
  self.data = {
    [ '6:0'  ] = 'sapling',
    [ '6:1'  ] = 'sapling',
    [ '6:2'  ] = 'sapling',
    [ '6:3'  ] = 'sapling',
    [ '6:4'  ] = 'sapling',
    [ '6:5'  ] = 'sapling',
    [ '8:0'  ] = 'truncate',
    [ '9:0'  ] = 'truncate',
    [ '17:0' ] = 'wood',
    [ '17:1' ] = 'wood',
    [ '17:2' ] = 'wood',
    [ '17:3' ] = 'wood',
    [ '18:0' ] = 'leaves',
    [ '18:1' ] = 'leaves',
    [ '18:2' ] = 'leaves',
    [ '18:3' ] = 'leaves',
    [ '23:0' ] = 'dispenser',
    [ '26:0' ] = 'bed',
    [ '27:0' ] = 'adp-rail',
    [ '28:0' ] = 'adp-rail',
    [ '29:0' ] = 'piston',
    [ '33:0' ] = 'piston',
    [ '34:0' ] = 'air',
    [ '36:0' ] = 'air',
    [ '44:0' ] = 'slab',
    [ '44:1' ] = 'slab',
    [ '44:2' ] = 'slab',
    [ '44:3' ] = 'slab',
    [ '44:4' ] = 'slab',
    [ '44:5' ] = 'slab',
    [ '44:6' ] = 'slab',
    [ '44:7' ] = 'slab',
    [ '50:0' ] = 'torch',
    [ '51:0' ] = 'flatten',
    [ '53:0' ] = 'stairs',
    [ '54:0' ] = 'chest-furnace',
    [ '55:0' ] = 'flatten',
    [ '59:0' ] = 'flatten',
    [ '60:0' ] = 'flatten',
    [ '61:0' ] = 'chest-furnace',
    [ '62:0' ] = 'chest-furnace',
    [ '63:0' ] = 'signpost',
    [ '64:0' ] = 'door',
    [ '65:0' ] = 'wallsign-ladder',
    [ '66:0' ] = 'rail',
    [ '67:0' ] = 'stairs',
    [ '68:0' ] = 'wallsign-ladder',
    [ '69:0' ] = 'lever',
    [ '71:0' ] = 'door',
    [ '75:0' ] = 'torch',
    [ '76:0' ] = 'torch',
    [ '77:0' ] = 'button',
    [ '78:0' ] = 'flatten',
    [ '81:0' ] = 'flatten',
    [ '83:0' ] = 'flatten',
    [ '84:0' ] = 'flatten',  -- jukebox
    [ '86:0' ] = 'pumpkin',
    [ '90:0' ] = 'air',
    [ '91:0' ] = 'pumpkin',
    [ '92:0' ] = 'flatten', -- cake
    [ '93:0' ] = 'repeater',
    [ '94:0' ] = 'repeater',
    [ '96:0' ] = 'trapdoor',
    [ '99:0' ] = 'flatten',
    [ '100:0' ] = 'flatten',
    [ '106:0' ] = 'vine',
    [ '107:0' ] = 'gate',
    [ '108:0' ] = 'stairs',
    [ '109:0' ] = 'stairs',
    [ '114:0' ] = 'stairs',
    [ '115:0' ] = 'flatten',
    [ '117:0' ] = 'flatten',
    [ '118:0' ] = 'cauldron',
    [ '120:0' ] = 'flatten', -- end portal
    [ '126:0' ] = 'slab',
    [ '126:1' ] = 'slab',
    [ '126:2' ] = 'slab',
    [ '126:3' ] = 'slab',
    [ '126:4' ] = 'slab',
    [ '126:5' ] = 'slab',
    [ '127:0' ] = 'cocoa',
    [ '128:0' ] = 'stairs',
    [ '130:0' ] = 'chest-furnace',
    [ '131:0' ] = 'tripwire',
    [ '132:0' ] = 'flatten',
    [ '134:0' ] = 'stairs',
    [ '135:0' ] = 'stairs',
    [ '136:0' ] = 'stairs',
    [ '140:0' ] = 'flatten',
    [ '141:0' ] = 'flatten',
    [ '142:0' ] = 'flatten',
    [ '143:0' ] = 'button',
    [ '144:0' ] = 'mobhead',
    [ '145:0' ] = 'anvil',
    [ '146:0' ] = 'chest-furnace',
    [ '149:0' ] = 'comparator',
    [ '151:0' ] = 'flatten',
    [ '154:0' ] = 'hopper',
    [ '155:2' ] = 'quartz-pillar',
    [ '156:0' ] = 'stairs',
    [ '157:0' ] = 'adp-rail',
    [ '158:0' ] = 'dispenser',
    [ '161:0' ] = 'leaves',
    [ '161:1' ] = 'leaves',
    [ '162:0' ] = 'wood',
    [ '162:1' ] = 'wood',
    [ '163:0' ] = 'stairs',
    [ '164:0' ] = 'stairs',
    [ '167:0' ] = 'trapdoor',
    [ '170:0' ] = 'hay-bale', -- hay bale
    [ '175:0' ] = 'largeplant',
    [ '175:1' ] = 'largeplant',
    [ '175:2' ] = 'largeplant', -- double tallgrass - an alternative would be to use grass as the bottom part, bonemeal as top part
    [ '175:3' ] = 'largeplant',
    [ '175:4' ] = 'largeplant',
    [ '175:5' ] = 'largeplant',
    [ '176:0' ] = 'signpost',
    [ '177:0' ] = 'wallsign-ladder',
    [ '178:0' ] = 'truncate',
    [ '180:0' ] = 'stairs',
    [ '182:0' ] = 'slab',
    [ '183:0' ] = 'gate',
    [ '184:0' ] = 'gate',
    [ '185:0' ] = 'gate',
    [ '186:0' ] = 'gate',
    [ '187:0' ] = 'gate',
    [ '193:0' ] = 'door',
    [ '194:0' ] = 'door',
    [ '195:0' ] = 'door',
    [ '196:0' ] = 'door',
    [ '197:0' ] = 'door',
    [ '198:0' ] = 'end_rod',  -- end rod
    [ '205:0' ] = 'slab',
    [ '210:0' ] = 'flatten',
    [ '355:0' ] = 'bed',
    [ '356:0' ] = 'repeater',
    [ '404:0' ] = 'comparator',
  }
  self.dirty = true
  -- self:flush()
end

--[[-- BlockTypeDB --]]--
local blockTypeDB = TableDB({
  fileName = 'blocktype.db',
  tabledef = {
    autokeys = true,
    columns = {
      { name = 'odmg',   type = 'number', length = 2 },
      { name = 'sid',    type = 'number', length = 5 },
      { name = 'sdmg',   type = 'number', length = 2 },
      { name = 'dir',    type = 'string', length = 20 },
    }
  }
})

function blockTypeDB:load(dir)
  self.fileName = fs.combine(dir, self.fileName)

  if fs.exists(self.fileName) then
    TableDB.load(self)
  else
    self:seedDB()
  end
end

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
 
function blockTypeDB:seedDB()
 
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
  blockTypeDB:addTemp('air', {
    {  0, 'minecraft:air', 0 },
    {  1, 'minecraft:air', 0 },
    {  2, 'minecraft:air', 0 },
    {  3, 'minecraft:air', 0 },
    {  4, 'minecraft:air', 0 },
    {  5, 'minecraft:air', 0 },
    {  6, 'minecraft:air', 0 },
    {  7, 'minecraft:air', 0 },
    {  8, 'minecraft:air', 0 },
    {  9, 'minecraft:air', 0 },
    { 10, 'minecraft:air', 0 },
    { 11, 'minecraft:air', 0 },
    { 12, 'minecraft:air', 0 },
    { 13, 'minecraft:air', 0 },
    { 14, 'minecraft:air', 0 },
    { 15, 'minecraft:air', 0 },
  })
  blockTypeDB:addTemp('truncate', {
    {  0, nil, 0 },
    {  1, 'minecraft:air', 0 },
    {  2, 'minecraft:air', 0 },
    {  3, 'minecraft:air', 0 },
    {  4, 'minecraft:air', 0 },
    {  5, 'minecraft:air', 0 },
    {  6, 'minecraft:air', 0 },
    {  7, 'minecraft:air', 0 },
    {  8, 'minecraft:air', 0 },
    {  9, 'minecraft:air', 0 },
    { 10, 'minecraft:air', 0 },
    { 11, 'minecraft:air', 0 },
    { 12, 'minecraft:air', 0 },
    { 13, 'minecraft:air', 0 },
    { 14, 'minecraft:air', 0 },
    { 15, 'minecraft:air', 0 },
  })
  blockTypeDB:addTemp('slab', {
    {  '+0', nil, nil, 'bottom' },
    {  '+8', nil, nil, 'top' },
  })
  blockTypeDB:addTemp('largeplant', {
    {  '+0', nil, nil, 'east-door' },   -- should use a generic double tall keyword
    {  '+8', 'minecraft:air', 0 },
  })
  blockTypeDB:addTemp('wood', {
    {  '+0',  nil, nil },
    {  '+4',  nil, nil, 'east-west-block' },
    {  '+8',  nil, nil, 'north-south-block' },
    {  '+12', nil, nil },
  })
  blockTypeDB:addTemp('door', {
    {  0, nil, 0, 'east-door',  { door = true } },
    {  1, nil, 0, 'south-door', { door = true } },
    {  2, nil, 0, 'west-door',  { door = true } },
    {  3, nil, 0, 'north-door', { door = true } },
    {  4, nil, 0, 'east-door',  { door = true } },
    {  5, nil, 0, 'south-door', { door = true } },
    {  6, nil, 0, 'west-door',  { door = true } },
    {  7, nil, 0, 'north-door', { door = true } },
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
  self.dirty = true
  -- self:flush()
end

local Blocks = class()
function Blocks:init(args)

  Util.merge(self, args)
  self.blockDB = blockDB
  self.nameDB = nameDB

  blockDB:load(self.dir)
  standardBlockDB:load(self.dir)
  blockTypeDB:load(self.dir)
  nameDB:load(self.dir, blockDB)
  placementDB:load(self.dir, standardBlockDB, blockTypeDB)
end

-- for an ID / dmg (with placement info) - return the correct block (without the placment info embedded in the dmg)
function Blocks:getRealBlock(id, dmg)

  local p = placementDB:get({id, dmg})
  if p then
    return {
      id = p.sid,
      dmg = p.sdmg,
      direction = p.direction,
      extra = p.extra,
      odmg = dmg
    }
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

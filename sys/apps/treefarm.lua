requireInjector(getfenv(1))

--[[
  Requirements:
    Place turtle against an oak tree or oak sapling
    Area around turtle must be flat and can only be dirt or grass
      (10 blocks in each direction from turtle)
    Turtle must have: crafting table, chest
    Turtle must have a pick equipped on the left side

  Optional:
    Add additional sapling types that can grow with a single sapling

  Notes:
    If the turtle does not get any saplings from the initial tree, place
    down another sapling in front of the turtle.

    The program will be able to survive server restarts as long as it has
    created the cobblestone line. If the program is stopped before that time,
    place the turtle in the original position before restarting the program.
]]--

local ChestAdapter = require('chestAdapter18')
local Craft        = require('turtle.craft')
local Level        = require('turtle.level')
local Point        = require('point')
local Util         = require('util')

local FUEL_BASE = 0
local FUEL_DIRE = FUEL_BASE + 10
local FUEL_GOOD = FUEL_BASE + 2000

local MIN_CHARCOAL = 24
local MAX_SAPLINGS = 32

local GRID_WIDTH = 8
local GRID_LENGTH = 10
local GRID = {
  TL = { x =  8, y = 0, z = -8 },
  TR = { x =  8, y = 0, z =  8 },
  BL = { x = -10, y = 0, z = -8 },
  BR = { x = -10, y = 0, z =  8 },
}

local HOME_PT = { x = 0, y = 0, z = 0, heading = 0 }

local DIG_BLACKLIST = {
  [ 'minecraft:furnace'     ] = true,
  [ 'minecraft:lit_furnace' ] = true,
  [ 'minecraft:chest'       ] = true,
}

local COBBLESTONE = 'minecraft:cobblestone:0'
local CHARCOAL    = 'minecraft:coal:1'
local OAK_LOG     = 'minecraft:log:0'
local OAK_PLANK   = 'minecraft:planks:0'
local CHEST       = 'minecraft:chest:0'
local FURNACE     = 'minecraft:furnace:0'
local SAPLING     = 'minecraft:sapling:0'
local STONE       = 'minecraft:stone:0'
local TORCH       = 'minecraft:torch:0'
local DIRT        = 'minecraft:dirt:0'
local APPLE       = 'minecraft:apple:0'
local STICK       = 'minecraft:stick:0'

local ALL_SAPLINGS = {
  SAPLING
}

local state = Util.readTable('usr/config/treefarm') or {
  trees = {
    { x = 1, y = 0, z = 0 }
  }
}

local clock = os.clock()
local recipes = Util.readTable('sys/etc/recipes.db') or { }

Craft.setRecipes(recipes)

local function inspect(fn)
  local s, item = fn()
  if s and item then
    return item.name .. ':' .. item.metadata
  end
  return 'minecraft:air:0'
end

local function setState(key, value)
  state[key] = value
  Util.writeTable('usr/config/treefarm', state)
end

local function refuel()
  if turtle.getFuelLevel() < FUEL_GOOD then
    local charcoal = turtle.getItemCount(CHARCOAL)
    if charcoal > 1 then
      turtle.refuel(CHARCOAL, math.min(charcoal - 1, MIN_CHARCOAL / 2))
      print('fuel: ' .. turtle.getFuelLevel())
    end
  end
  return true
end

local function safePlaceBlock(item)

  if turtle.placeUp(item) then
    return true
  end

  local s, m = turtle.inspectUp()
  if s and not DIG_BLACKLIST[m.name] then
    turtle.digUp()
    return turtle.placeUp(item)
  end

  turtle.forward()
  return turtle.placeUp(item)
end

local function craftItem(item, qty)

  local success

  if safePlaceBlock(CHEST) then

    if turtle.equip('left', 'minecraft:crafting_table') then

      local chestAdapter = ChestAdapter({
        wrapSide = 'top',
        direction = 'down',
      })
      if not chestAdapter:isValid() then
        print('invalid chestAdapter')
        read()
      end
      -- turtle.emptyInventory(turtle.dropUp)

      Util.print('Crafting %d %s', (qty or 1), item)
      success = Craft.craftRecipe(recipes[item], qty or 1, chestAdapter)

      repeat until not turtle.suckUp()
    end
    turtle.equip('left', 'minecraft:diamond_pickaxe')
    turtle.digUp()
  end

  return success
end

local function cook(item, count, result, fuel, fuelCount)

  setState('cooking', true)

  fuel = fuel or CHARCOAL
  fuelCount = fuelCount or math.ceil(count / 8)
  Util.print('Making %d %s', count, result)

  turtle.dropForwardAt(state.furnace, fuel, fuelCount)
  turtle.dropDownAt(state.furnace, item, count)

  count = count + turtle.getItemCount(result)
  turtle.select(1)
  turtle.pathfind(Point.below(state.furnace))
  repeat
    os.sleep(1)
    turtle.suckUp()
  until turtle.getItemCount(result) >= count

  setState('cooking')
end

local function makeSingleCharcoal()

  local slots = turtle.getSummedInventory()

  if not state.furnace or 
     slots[CHARCOAL] or
     not slots[OAK_LOG] or
     slots[OAK_LOG].count < 2 then
    return true
  end

  turtle.faceAgainst(state.furnace)
  if craftItem(OAK_PLANK) then
    cook(OAK_LOG, 1, CHARCOAL, OAK_PLANK, 1)
    turtle.refuel(OAK_PLANK)
  end

  return true
end

local function makeCharcoal()

  local slots = turtle.getSummedInventory()

  if not state.furnace or 
     not slots[CHARCOAL] or
     slots[CHARCOAL].count >= MIN_CHARCOAL then
    return true
  end

  local function getLogSlot(slots)
    local maxslot = { count = 0 }
    for k,slot in pairs(slots) do
      if string.match(k, 'minecraft:log') then
        if slot.count > maxslot.count then
          maxslot = slot
        end
      end
    end
    return maxslot
  end

  repeat
    local slots    = turtle.getSummedInventory()
    local charcoal = slots[CHARCOAL].count
    local slot     = getLogSlot(slots)

    if slot.count < 8 then
      break
    end

    local toCook = math.min(charcoal, math.floor(slot.count / 8))
    toCook = math.min(toCook, math.floor((MIN_CHARCOAL + 8 - charcoal) / 8))
    toCook = toCook * 8

    cook(slot.key, toCook, CHARCOAL)

  until charcoal + toCook >= MIN_CHARCOAL

  return true
end

local function emptyFurnace()
  if state.cooking then

    print('Emptying furnace')

    turtle.suckDownAt(state.furnace)
    turtle.suckForwardAt(state.furnace)
    turtle.suckUpAt(state.furnace)
    setState('cooking')
  end
end

local function getCobblestone(count)

  local slots = turtle.getSummedInventory()

  if not slots[COBBLESTONE] or slots[COBBLESTONE].count < count then

    print('Collecting cobblestone')

    slots[COBBLESTONE] = true
    slots[DIRT] = true

    local pt = Point.copy(GRID.BR)
    pt.x = GRID.BR.x + 2
    pt.z = GRID.BR.z - 2

    turtle.pathfind(pt)

    repeat
      turtle.select(1)
      turtle.digDown()
      turtle.down()
      for i = 1, 4 do
        if inspect(turtle.inspect) == STONE then
          turtle.dig()
        end
        turtle.turnRight()
      end

      for item in pairs(turtle.getSummedInventory()) do
        if not slots[item] then
          turtle.drop(item)
        end
      end

    until turtle.getItemCount(COBBLESTONE) >= count

    turtle.gotoPoint(pt)
    turtle.placeDown(DIRT)

    turtle.drop(DIRT)
  end
end

local function createFurnace()

  if not state.furnace then
    if turtle.getFuelLevel() < FUEL_BASE + 100 then
      return true -- try again later
    end
    print('Adding a furnace')
    getCobblestone(8)

    if craftItem(FURNACE) then
      turtle.drop(COBBLESTONE)
      local furnacePt = { x = GRID.BL.x + 2, y = 1, z = GRID.BL.z + 2 }
      turtle.placeAt(furnacePt, FURNACE)
      setState('furnace', furnacePt)
    end
  end
end

local function createPerimeter()

  if not state.perimeter then
    if not state.furnace or
       turtle.getFuelLevel() < FUEL_BASE + 500 or
       turtle.getItemCount(OAK_LOG) == 0 or
       not craftItem(OAK_PLANK, 2) then
      return true
    end

    print('Creating a perimeter')

    getCobblestone(GRID_WIDTH * 2 + 1)
    cook(COBBLESTONE, 2, STONE, OAK_PLANK, 2)
    turtle.refuel(OAK_PLANK)

    turtle.pathfind(GRID.BL)
    turtle.digDown()
    turtle.placeDown(STONE)

    turtle.setMoveCallback(function()
      local target = COBBLESTONE
      if math.abs(turtle.point.x) == GRID_LENGTH and
         math.abs(turtle.point.z) == GRID_WIDTH then
         target = STONE
       end

      if inspect(turtle.inspectDown) ~= target then
        turtle.digDown()
        turtle.placeDown(target)
      end
    end)

    turtle.pathfind(GRID.BR)

    turtle.clearMoveCallback()
    turtle.drop(COBBLESTONE)
    turtle.drop(DIRT)

    setState('perimeter', true)
  end
end

local function createChests()
  if state.chest_1 then
    return false
  end
  if state.perimeter and
     turtle.getFuelLevel() > FUEL_GOOD and
     Craft.canCraft(CHEST, 4, turtle.getSummedInventory()) then

    print('Adding storage')
    if craftItem(CHEST, 4) then

      local pt = Point.copy(GRID.BL)
      pt.x = pt.x + 1
      pt.y = pt.y - 1

      for i = 1, 2 do
        pt.z = pt.z + 1

        turtle.digDownAt(pt)
        turtle.placeDown(CHEST)

        pt.z = pt.z + 1

        turtle.digDownAt(pt)
        turtle.placeDown(CHEST)

        setState('chest_' .. i, Util.shallowCopy(pt))

        pt.z = pt.z + 1
      end
      turtle.drop(DIRT)
      turtle.refuel(OAK_PLANK)
    end
  end
  return true
end

local function dropOffItems()

  if state.chest_1 then
    local slots = turtle.getSummedInventory()

    if state.chest_1 and 
       slots[CHARCOAL] and 
       slots[CHARCOAL].count >= MIN_CHARCOAL and 
       (turtle.getItemCount('minecraft:log') > 0 or
        turtle.getItemCount('minecraft:log2') > 0) then

      print('Storing logs')
      turtle.pathfind(state.chest_1)
      turtle.dropDown('minecraft:log')
      turtle.dropDown('minecraft:log2')
    end

    if slots[APPLE] then
      print('Storing apples')
      turtle.dropDownAt(state.chest_2, APPLE)
    end
  end

  return true
end

local function eatSaplings()

  local slots = turtle.getSummedInventory()

  for _, sapling in pairs(ALL_SAPLINGS) do
    if slots[sapling] and slots[sapling].count > MAX_SAPLINGS then
      turtle.refuel(sapling, slots[sapling].count - MAX_SAPLINGS)
    end
  end
  return true
end

local function placeTorches()
  if state.torches then
    return
  end

  if turtle.getFuelLevel() > 100 and
     Craft.canCraft(TORCH, 4, turtle.getSummedInventory()) then

    print('Placing torches')

    if craftItem(TORCH, 4) then
      local pts = { }
      for x = -4, 4, 8 do
        for z = -4, 4, 8 do
          table.insert(pts, { x = x, y = 0, z = z })
        end
      end
      Point.eachClosest(turtle.point, pts, function(pt)
        turtle.placeAt(pt, TORCH)
      end)
      turtle.refuel(STICK)
      turtle.refuel(OAK_PLANK)
      setState('torches', true)
    end
  end

  return true
end

local function randomSapling()

  local sapling = SAPLING

  if #state.trees > 1 then
    ALL_SAPLINGS = { }

    local slots = turtle.getFilledSlots()
    for _, slot in pairs(slots) do
      if slot.name == 'minecraft:sapling' then
        table.insert(ALL_SAPLINGS, slot.key)
      end
    end
    sapling = ALL_SAPLINGS[math.random(1, #ALL_SAPLINGS)]
  end

  return sapling
end

local function fellTree(pt)

  local function desparateRefuel(min)
    if turtle.getFuelLevel() < min then
      local logs = turtle.getItemCount(OAK_LOG)
      if logs > 0 then
        if craftItem(OAK_PLANK, math.min(8, logs * 4)) then
          turtle.refuel(OAK_PLANK)
          print('fuel: ' .. turtle.getFuelLevel())
        end
      end
    end
  end

  turtle.setMoveCallback(function() desparateRefuel(FUEL_DIRE) end)

  desparateRefuel(FUEL_DIRE)

  if turtle.digUpAt(Point.above(pt)) then
    Level(
      { x = GRID_WIDTH-1,    y = 1,  z = GRID_WIDTH-1    },
      { x = -(GRID_WIDTH-1), y = 50, z = -(GRID_WIDTH-1) },
      Point.above(pt))
  end

  desparateRefuel(FUEL_BASE + 100)
  turtle.clearMoveCallback()
  turtle.setPolicy("attack")

  return true
end

local function fell()

  local pts = Util.shallowCopy(state.trees)

  local pt = table.remove(pts, math.random(1, #pts))
  if not turtle.faceAgainst(pt) or
     not string.match(inspect(turtle.inspect), 'minecraft:log') then
    return true
  end

  print('Chopping')

  local fuel = turtle.getFuelLevel()
  table.insert(pts, 1, pt)

  Point.eachClosest(turtle.point, pts, function(pt)
    if turtle.faceAgainst(pt) and
       string.match(inspect(turtle.inspect), 'minecraft:log') then
      turtle.dig()
      fellTree(pt)
    end
    turtle.placeAt(pt, randomSapling())
    turtle.select(1)
  end)

  print('Used ' .. (fuel - turtle.getFuelLevel()) .. ' fuel')
  return true
end

local function moreTrees()

  if #state.trees > 1 then
    return
  end

  if not state.chest_1 or turtle.getItemCount(SAPLING) < 9 then
    return true
  end

  print('Adding more trees')

  local singleTree = state.trees[1]

  state.trees = { }
  for x = -2, 2, 2 do
    for z = -2, 2, 2 do
      table.insert(state.trees, { x = x, y = 0, z = z })
    end
  end

  turtle.digAt(singleTree)
  fellTree(singleTree)

  setState('trees', state.trees)

  Point.eachClosest(turtle.point, state.trees, function(pt)
    turtle.placeDownAt(pt, randomSapling())
  end)
end

function getTurtleFacing(block)
  local directions = {
    [5] = 2,
    [3] = 3,
    [4] = 0,
    [2] = 1,
  }

  if not safePlaceBlock(block) then
    error('unable to place chest above')
  end
  local _, bi = turtle.inspectUp()
  turtle.digUp()
  return directions[bi.metadata]
end

function saveTurtleFacing()
  if not state.facing then
    setState('facing', getTurtleFacing(CHEST))
  end
end

local function findGround()
  print('Locating ground level')
  turtle.setPoint(HOME_PT)

  while true do
    local s, block = turtle.inspectDown()

    if not s then block = { name = 'minecraft:air', metadata = 0 } end
    b = block.name .. ':' .. block.metadata

    if b == 'minecraft:dirt:0' or 
       b == 'minecraft:grass:0' or
       block.name == 'minecraft:chest' then
      break
    end

    if b == COBBLESTONE or b == STONE then
      error('lost')
    end

    if b == TORCH or b == FURNACE then
      turtle.forward()
    else
      turtle.digDown()
      turtle.down()
    end

    if turtle.point.y < -20 then
      error('lost')
    end
  end
  turtle.setPoint(HOME_PT)
end

local function findHome()

  if not state.perimeter then
    return
  end

  print('Determining location')

  turtle.point.heading = getTurtleFacing(CHEST)
  turtle.setHeading(state.facing)
  turtle.point.heading = 0

  local pt = Point.copy(turtle.point)

  while inspect(turtle.inspectDown) ~= COBBLESTONE do
    pt.x = pt.x - 1
    turtle.pathfind(pt)
    if pt.x < -20 then
      error('lost')
    end
  end
  while inspect(turtle.inspectDown) == COBBLESTONE do
    pt.z = pt.z - 1
    turtle.pathfind(pt)
    if pt.z < -20 then
      error('lost')
    end
  end

  turtle.setPoint({
    x = -(GRID_LENGTH),
    y = 0,
    z = -GRID_WIDTH,
    heading = turtle.point.heading
  })
end

local function updateClock()

  local ONE_HOUR = 50

  if os.clock() - clock > ONE_HOUR then
    clock = os.clock()
  else
    print('sleeping for ' .. math.floor(ONE_HOUR - (os.clock() - clock)))
    os.sleep(ONE_HOUR - (os.clock() - clock))
    clock = os.clock()
  end

  return true
end

local tasks = {
  { desc = 'Finding ground',     fn = findGround         },
  { desc = 'Determine facing',   fn = saveTurtleFacing   },
  { desc = 'Finding home',       fn = findHome           },
  { desc = 'Adding trees',       fn = moreTrees          },
  { desc = 'Chopping',           fn = fell               },
  { desc = 'Snacking',           fn = eatSaplings        },
  { desc = 'Creating chest',     fn = createChests       },
  { desc = 'Creating furnace',   fn = createFurnace      },
  { desc = 'Emptying furnace',   fn = emptyFurnace       },
  { desc = 'Making charcoal',    fn = makeSingleCharcoal },
  { desc = 'Making charcoal',    fn = makeCharcoal       },
  { desc = 'Creating perimeter', fn = createPerimeter    },
  { desc = 'Placing torches',    fn = placeTorches       },
  { desc = 'Refueling',          fn = refuel             },
  { desc = 'Dropping off items', fn = dropOffItems       },
  { desc = 'Condensing',         fn = turtle.condense    },  
  { desc = 'Sleeping',           fn = updateClock        },
}

turtle.run(function()

  turtle.setPolicy("attack")

  while not turtle.abort do
    print('fuel: ' .. turtle.getFuelLevel())
    for _,task in ipairs(Util.shallowCopy(tasks)) do
      --print(task.desc)
      turtle.status = task.desc
      turtle.select(1)
      if not task.fn() then
        Util.filterInplace(tasks, function(v) return v.fn ~= task.fn end) 
      end
    end
  end
end)

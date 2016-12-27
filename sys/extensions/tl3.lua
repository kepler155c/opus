if not turtle then
  return
end

local function noop() end

turtle.point = { x = 0, y = 0, z = 0, heading = 0 }
turtle.status = 'idle'
turtle.abort = false

function turtle.getPoint()
  return turtle.point
end

local state = {
  moveAttack = noop,
  moveDig = noop,
  moveCallback = noop,
  locations = {},
  coordSystem = 'relative', -- type of coordinate system being used
}

function turtle.getState()
  return state
end

function turtle.setPoint(pt)
  turtle.point.x = pt.x
  turtle.point.y = pt.y
  turtle.point.z = pt.z
  if pt.heading then
    turtle.point.heading = pt.heading
  end
  return true
end

function turtle.reset()
  turtle.point.x = 0
  turtle.point.y = 0
  turtle.point.z = 0
  turtle.point.heading = 0
  turtle.abort = false -- should be part of state
  --turtle.status = 'idle' -- should be part of state
  state.moveAttack = noop
  state.moveDig = noop
  state.moveCallback = noop
  state.locations = {}
  state.coordSystem = 'relative'

  return true
end

local actions = {
  up = {
    detect = turtle.native.detectUp,
    dig = turtle.native.digUp,
    move = turtle.native.up,
    attack = turtle.native.attackUp,
    place = turtle.native.placeUp,
    drop = turtle.native.dropUp,
    suck = turtle.native.suckUp,
    compare = turtle.native.compareUp,
    inspect = turtle.native.inspectUp,
    side = 'top'
  },
  down = {
    detect = turtle.native.detectDown,
    dig = turtle.native.digDown,
    move = turtle.native.down,
    attack = turtle.native.attackDown,
    place = turtle.native.placeDown,
    drop = turtle.native.dropDown,
    suck = turtle.native.suckDown,
    compare = turtle.native.compareDown,
    inspect = turtle.native.inspectDown,
    side = 'bottom'
  },
  forward = {
    detect = turtle.native.detect,
    dig = turtle.native.dig,
    move = turtle.native.forward,
    attack = turtle.native.attack,
    place = turtle.native.place,
    drop = turtle.native.drop,
    suck = turtle.native.suck,
    compare = turtle.native.compare,
    inspect = turtle.native.inspect,
    side = 'front'
  },
  back = {
    detect = noop,
    dig = noop,
    move = turtle.native.back,
    attack = noop,
    place = noop,
    suck = noop,
    compare = noop,
    side = 'back'
  },
}

function turtle.getAction(direction)
  return actions[direction]
end

-- [[ Heading data ]] --
local headings = {
  [ 0 ] = { xd =  1, zd =  0, yd =  0, heading = 0, direction = 'east' },
  [ 1 ] = { xd =  0, zd =  1, yd =  0, heading = 1, direction = 'south' },
  [ 2 ] = { xd = -1, zd =  0, yd =  0, heading = 2, direction = 'west' },
  [ 3 ] = { xd =  0, zd = -1, yd =  0, heading = 3, direction = 'north' },
  [ 4 ] = { xd =  0, zd =  0, yd =  1, heading = 4, direction = 'up' },
  [ 5 ] = { xd =  0, zd =  0, yd = -1, heading = 5, direction = 'down' }
}

local namedHeadings = {
  east  = headings[0],
  south = headings[1],
  west  = headings[2],
  north = headings[3],
  up    = headings[4],
  down  = headings[5]
}

function turtle.getHeadings()
  return headings
end

function turtle.getHeadingInfo(heading)
  if heading and type(heading) == 'string' then
    return namedHeadings[heading]
  end
  heading = heading or turtle.point.heading
  return headings[heading]
end

-- [[ Basic turtle actions ]] --
local function _attack(action)
  if action.attack() then
    repeat until not action.attack()
    return true
  end
  return false
end

function turtle.attack()        return _attack(actions.forward) end
function turtle.attackUp()      return _attack(actions.up)      end
function turtle.attackDown()    return _attack(actions.down)    end

local function _place(action, indexOrId)

  local slot

  if indexOrId then
    slot = turtle.getSlot(indexOrId)
    if not slot then
      return false, 'No items to place'
    end
  end

  if slot and slot.qty == 0 then
    return false, 'No items to place'
  end

  return Util.tryTimes(3, function()
    if slot then
      turtle.select(slot.index)
    end
    local result = { action.place() }
    if result[1] then
      return true
    end
    if not state.moveDig(action) then
      state.moveAttack(action)
    end
    return unpack(result)
  end)
end

function turtle.place(slot)     return _place(actions.forward, slot) end
function turtle.placeUp(slot)   return _place(actions.up, slot)      end
function turtle.placeDown(slot) return _place(actions.down, slot)    end

local function _drop(action, count, indexOrId)

  if indexOrId then
    local slot = turtle.getSlot(indexOrId)
    if not slot or slot.qty == 0 then
      return false, 'No items to drop'
    end
    turtle.select(slot.index)
  end
  if not count then
    return action.drop() -- wtf
  end
  return action.drop(count)
end

function turtle.drop(count, slot)     return _drop(actions.forward, count, slot) end
function turtle.dropUp(count, slot)   return _drop(actions.up, count, slot)      end
function turtle.dropDown(count, slot) return _drop(actions.down, count, slot)    end

--[[
function turtle.dig()           return state.dig(actions.forward) end
function turtle.digUp()         return state.dig(actions.up)      end
function turtle.digDown()       return state.dig(actions.down)    end
--]]

function turtle.isTurtleAtSide(side)
  local sideType = peripheral.getType(side)
  return sideType and sideType == 'turtle'
end

turtle.attackPolicies = {
  none = noop,

  attack = function(action)
    return _attack(action)
  end,
}

turtle.digPolicies = {
  none = noop,

  dig = function(action)
    return action.dig()
  end,

  turtleSafe = function(action)
    if action.side == 'back' then
      return false
    end
    if not turtle.isTurtleAtSide(action.side) then
      return action.dig()
    end
    return Util.tryTimes(6, function()
--      if not turtle.isTurtleAtSide(action.side) then
--        return true --action.dig()
--      end
      os.sleep(.25)
      if not action.detect() then
        return true
      end
    end)
  end,

  digAndDrop = function(action)
    if action.detect() then
      local slots = turtle.getInventory()
      if action.dig() then
        turtle.reconcileInventory(slots)
        return true
      end
    end
    return false
  end
}

turtle.policies = {
  none       = { dig = turtle.digPolicies.none,        attack = turtle.attackPolicies.none },
  digOnly    = { dig = turtle.digPolicies.dig,         attack = turtle.attackPolicies.none },
  attackOnly = { dig = turtle.digPolicies.none,        attack = turtle.attackPolicies.attack },
  digAttack  = { dig = turtle.digPolicies.dig,         attack = turtle.attackPolicies.attack },
  turtleSafe = { dig = turtle.digPolicies.turtleSafe,  attack = turtle.attackPolicies.attack },
}

function turtle.setPolicy(policy)
  if type(policy) == 'string' then
    policy = turtle.policies[policy]
  end
  if not policy then
    return false, 'Invalid policy'
  end
  state.moveDig = policy.dig
  state.moveAttack = policy.attack
  return true
end

function turtle.setDigPolicy(policy)
  state.moveDig = policy
end

function turtle.setAttackPolicy(policy)
  state.moveAttack = policy
end

function turtle.setMoveCallback(cb)
  state.moveCallback = cb
end

function turtle.clearMoveCallback()
  state.moveCallback = noop
end

local function infoMoveCallback()
  local pt = turtle.point
  print(string.format('x:%d y:%d z:%d heading:%d', pt.x, pt.y, pt.z, pt.heading))
end
-- TESTING
--turtle.setMoveCallback(infoMoveCallback)

-- [[ Locations ]] --
function turtle.getLocation(name)
  return state.locations[name]
end

function turtle.saveLocation(name, pt)
  pt = pt or turtle.point
  state.locations[name] = { x = pt.x, y = pt.y, z = pt.z }
end

function turtle.gotoLocation(name)
  local pt = turtle.getLocation(name)
  if pt then
    return turtle.goto(pt.x, pt.z, pt.y, pt.heading)
  end
end

function turtle.storeLocation(name, pt)
  pt = pt or turtle.point
  Util.writeTable(name .. '.pt', pt)
  return true
end

function turtle.loadLocation(name)
  return Util.readTable(name .. '.pt')
end

function turtle.gotoStoredLocation(name)
  local pt = turtle.loadLocation(name)
  if pt then
    return turtle.gotoPoint(pt)
  end
end

-- [[ Heading ]] --
function turtle.getHeading()
  return turtle.point.heading
end

function turtle.turnRight()
  turtle.setHeading(turtle.point.heading + 1)
  return turtle.point
end

function turtle.turnLeft()
  turtle.setHeading(turtle.point.heading - 1)
  return turtle.point
end

function turtle.turnAround()
  turtle.setHeading(turtle.point.heading + 2)
  return turtle.point
end

function turtle.setNamedHeading(headingName)
  local headingInfo = namedHeadings[headingName]
  if headingInfo then 
    return turtle.setHeading(headingInfo.heading)
  end
  return false, 'Invalid heading'
end

function turtle.setHeading(heading)
  if not heading then
    return
  end

  heading = heading % 4
  if heading ~= turtle.point.heading then
    while heading < turtle.point.heading do
      heading = heading + 4
    end
    if heading - turtle.point.heading == 3 then
      turtle.native.turnLeft()
      turtle.point.heading = turtle.point.heading - 1
    else
      local turns = heading - turtle.point.heading
      while turns > 0 do
        turns = turns - 1
        turtle.point.heading = turtle.point.heading + 1
        turtle.native.turnRight()
      end
    end

    turtle.point.heading = turtle.point.heading % 4
    state.moveCallback('turn', turtle.point)
  end

  return turtle.point
end

function turtle.headTowardsX(dx)
  if turtle.point.x ~= dx then
    if turtle.point.x > dx then
      turtle.setHeading(2)
    else
      turtle.setHeading(0)
    end
  end
end

function turtle.headTowardsZ(dz)
  if turtle.point.z ~= dz then
    if turtle.point.z > dz then
      turtle.setHeading(3)
    else
      turtle.setHeading(1)
    end
  end
end

function turtle.headTowards(pt)
  local xd = math.abs(turtle.point.x - pt.x)
  local zd = math.abs(turtle.point.z - pt.z)
  if xd > zd then
    turtle.headTowardsX(pt.x)
  else
    turtle.headTowardsZ(pt.z)
  end
end

-- [[ move ]] --
local function _move(action)
  while not action.move() do
    if not state.moveDig(action) and not state.moveAttack(action) then
      return false
    end
  end
  return true
end

function turtle.up()
  if _move(actions.up) then
    turtle.point.y = turtle.point.y + 1
    state.moveCallback('up', turtle.point)
    return true, turtle.point
  end
end

function turtle.down()
  if _move(actions.down) then
    turtle.point.y = turtle.point.y - 1
    state.moveCallback('down', turtle.point)
    return true, turtle.point
  end
end

function turtle.forward()
  if _move(actions.forward) then
    turtle.point.x = turtle.point.x + headings[turtle.point.heading].xd
    turtle.point.z = turtle.point.z + headings[turtle.point.heading].zd
    state.moveCallback('forward', turtle.point)
    return true, turtle.point
  end
end

function turtle.back()
  if _move(actions.back) then
    turtle.point.x = turtle.point.x - headings[turtle.point.heading].xd
    turtle.point.z = turtle.point.z - headings[turtle.point.heading].zd
    state.moveCallback('back', turtle.point)
    return true, turtle.point
  end
end

function turtle.moveTowardsX(dx)

  local direction = dx - turtle.point.x
  local move
  
  if direction == 0 then
    return true
  end
  
  if direction > 0 and turtle.point.heading == 0 or
     direction < 0 and turtle.point.heading == 2 then
    move = turtle.forward
  else
    move = turtle.back
  end

  repeat
    if not move() then
      return false
    end
  until turtle.point.x == dx
  return true
end

function turtle.moveTowardsZ(dz)

  local direction = dz - turtle.point.z
  local move

  if direction == 0 then
    return true
  end
  
  if direction > 0 and turtle.point.heading == 1 or
     direction < 0 and turtle.point.heading == 3 then
    move = turtle.forward
  else
    move = turtle.back
  end

  repeat
    if not move() then
      return false
    end
  until turtle.point.z == dz
  return true
end

-- [[ go ]] --
-- 1 turn goto (going backwards if possible)
function turtle.gotoSingleTurn(dx, dz, dy, dh)

  dy = dy or turtle.point.y

  local function gx()
    if turtle.point.x ~= dx then
      turtle.moveTowardsX(dx)
    end
    if turtle.point.z ~= dz then
      if dh and dh % 2 == 1 then
        turtle.setHeading(dh)
      else
        turtle.headTowardsZ(dz)
      end
    end
  end

  local function gz()
    if turtle.point.z ~= dz then
      turtle.moveTowardsZ(dz)
    end
    if turtle.point.x ~= dx then
      if dh and dh % 2 == 0 then
        turtle.setHeading(dh)
      else
        turtle.headTowardsX(dx)
      end
    end
  end

  repeat
    local x, z
    local y = turtle.point.y

    repeat
      x, z = turtle.point.x, turtle.point.z

      if turtle.point.heading % 2 == 0 then
        gx()
        gz()
      else
        gz()
        gx()
      end
    until x == turtle.point.x and z == turtle.point.z

    if turtle.point.y ~= dy then
      turtle.gotoY(dy)
    end

    if turtle.point.x == dx and turtle.point.z == dz and turtle.point.y == dy then
      return true
    end

  until x == turtle.point.x and z == turtle.point.z and y == turtle.point.y

  return false
end

local function gotoEx(dx, dz, dy)

  -- determine the heading to ensure the least amount of turns
  -- first check is 1 turn needed - remaining require 2 turns
  if turtle.point.heading == 0 and turtle.point.x <= dx or 
     turtle.point.heading == 2 and turtle.point.x >= dx or 
     turtle.point.heading == 1 and turtle.point.z <= dz or 
     turtle.point.heading == 3 and turtle.point.z >= dz then 
    -- maintain current heading
    -- nop
  elseif dz > turtle.point.z and turtle.point.heading == 0 or 
         dz < turtle.point.z and turtle.point.heading == 2 or
         dx < turtle.point.x and turtle.point.heading == 1 or
         dx > turtle.point.x and turtle.point.heading == 3 then
    turtle.turnRight()
  else
    turtle.turnLeft()
  end

  if (turtle.point.heading % 2) == 1 then
    if not turtle.gotoZ(dz) then return false end
    if not turtle.gotoX(dx) then return false end
  else
    if not turtle.gotoX(dx) then return false end
    if not turtle.gotoZ(dz) then return false end
  end

  if dy then
    if not turtle.gotoY(dy) then return false end
  end

  return true
end

-- fallback goto - will turn around if was previously moving backwards
local function gotoMultiTurn(dx, dz, dy)

  if gotoEx(dx, dz, dy) then
    return true
  end

  local moved
  repeat
    local x, y, z = turtle.point.x, turtle.point.y, turtle.point.z

    -- try going the other way
    if (turtle.point.heading % 2) == 1 then
      turtle.headTowardsX(dx)
    else
      turtle.headTowardsZ(dz)
    end

    if gotoEx(dx, dz, dy) then
      return true
    end

    if dy then
      turtle.gotoY(dy)
    end

    moved = x ~= turtle.point.x or y ~= turtle.point.y or z ~= turtle.point.z
  until not moved

  return false
end

function turtle.gotoPoint(pt)
  return turtle.goto(pt.x, pt.z, pt.y, pt.heading)
end

-- go backwards - turning around if necessary to fight mobs / break blocks
function turtle.goback()
  local hi = headings[turtle.point.heading]
  return turtle.goto(turtle.point.x - hi.xd, turtle.point.z - hi.zd, turtle.point.y, turtle.point.heading)
end

function turtle.gotoYfirst(pt)
  if turtle.gotoY(pt.y) then
    if turtle.goto(pt.x, pt.z, nil, pt.heading) then
      turtle.setHeading(pt.heading)
      return true
    end
  end
end

function turtle.gotoYlast(pt)
  if turtle.goto(pt.x, pt.z, nil, pt.heading) then
    if turtle.gotoY(pt.y) then
      turtle.setHeading(pt.heading)
      return true
    end
  end
end

function turtle.goto(dx, dz, dy, dh)
  if not turtle.gotoSingleTurn(dx, dz, dy, dh) then
    if not gotoMultiTurn(dx, dz, dy) then
      return false
    end
  end
  turtle.setHeading(dh)
  return true
end

function turtle.gotoX(dx)
  turtle.headTowardsX(dx)

  while turtle.point.x ~= dx do
    if not turtle.forward() then
      return false
    end
  end
  return true
end

function turtle.gotoZ(dz)
  turtle.headTowardsZ(dz)

  while turtle.point.z ~= dz do
    if not turtle.forward() then
      return false
    end
  end
  return true
end

function turtle.gotoY(dy)
  while turtle.point.y > dy do
    if not turtle.down() then
      return false
    end
  end
  
  while turtle.point.y < dy do
    if not turtle.up() then
      return false
    end
  end
  return true
end

-- [[ Slot management ]] --
function turtle.getSlot(indexOrId, slots)

  if type(indexOrId) == 'string' then
    slots = slots or turtle.getInventory()
    local _,c = string.gsub(indexOrId, ':', '')
    if c == 2 then -- combined id and dmg .. ie. minecraft:coal:0
      return Util.find(slots, 'iddmg', indexOrId)
    end
    return Util.find(slots, 'id', indexOrId)
  end

  local detail = turtle.getItemDetail(indexOrId)
  if detail then
    return {
      qty = detail.count,
      dmg = detail.damage,
      id = detail.name,
      iddmg = detail.name .. ':' .. detail.damage,
      index = indexOrId,
    }
  end

  return {
    qty = 0,
    index = indexOrId,
  }
end

function turtle.selectSlot(indexOrId)

  local s = turtle.getSlot(indexOrId)
  if s then
    turtle.select(s.index)
    return s
  end

  return false, 'Inventory does not contain item'
end

function turtle.getInventory(slots)
  slots = slots or { }
  for i = 1, 16 do
    slots[i] = turtle.getSlot(i)
  end
  return slots
end

function turtle.emptyInventory(dropAction)
  dropAction = dropAction or turtle.drop
  for i = 1, 16 do
    turtle.emptySlot(i, dropAction)
  end
end

function turtle.emptySlot(slot, dropAction)
  dropAction = dropAction or turtle.drop
  local count = turtle.getItemCount(slot)
  if count > 0 then
    turtle.select(slot)
    return dropAction(count)
  end
  return false, 'No items to drop'
end

function turtle.getFilledSlots(startSlot)
  startSlot = startSlot or 1

  local slots = { }
  for i = startSlot, 16 do
    local count = turtle.getItemCount(i)
    if count > 0 then
      slots[i] = turtle.getSlot(i)
    end
  end
  return slots
end

function turtle.eachFilledSlot(fn)
  local slots = turtle.getFilledSlots()
  for _,slot in pairs(slots) do
    fn(slot)
  end
end

function turtle.reconcileInventory(slots, dropAction)
  dropAction = dropAction or turtle.native.drop
  for _,s in pairs(slots) do
    local qty = turtle.getItemCount(s.index)
    if qty > s.qty then
      turtle.select(s.index)
      dropAction(qty-s.qty, s)
    end
  end
end

function turtle.selectSlotWithItems(startSlot)
  startSlot = startSlot or 1
  for i = startSlot, 16 do
    if turtle.getItemCount(i) > 0 then
      turtle.select(i)
      return i
    end
  end
end

function turtle.selectOpenSlot(startSlot)
  return turtle.selectSlotWithQuantity(0, startSlot)
end

function turtle.selectSlotWithQuantity(qty, startSlot)
  startSlot = startSlot or 1

  for i = startSlot, 16 do
    if turtle.getItemCount(i) == qty then
      turtle.select(i)
      return i
    end
  end
end

function turtle.condense(startSlot)
  startSlot = startSlot or 1
  local aslots = turtle.getInventory()
  
  for _,slot in ipairs(aslots) do
    if slot.qty < 64 then
      for i = slot.index + 1, 16 do
        local fslot = aslots[i]
        if fslot.qty > 0 then
          if slot.qty == 0 or slot.iddmg == fslot.iddmg then
            turtle.select(fslot.index)
            turtle.transferTo(slot.index, 64)
            local transferred = turtle.getItemCount(slot.index) - slot.qty
            slot.qty = slot.qty + transferred
            fslot.qty = fslot.qty - transferred
            slot.iddmg = fslot.iddmg
            if slot.qty == 64 then
              break
            end
          end
        end
      end
    end
  end
end

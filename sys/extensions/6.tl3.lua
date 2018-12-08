if not _G.turtle then
	return
end

_G.requireInjector(_ENV)

local Pathing      = require('turtle.pathfind')
local GPS          = require('gps')
local Point        = require('point')
local synchronized = require('sync').sync
local Util         = require('util')

local os         = _G.os
local peripheral = _G.peripheral
local turtle     = _G.turtle

local function noop() end
local headings = Point.headings
local state = { }

turtle.pathfind = Pathing.pathfind
turtle.point = { x = 0, y = 0, z = 0, heading = 0 }

function turtle.getPoint()   return turtle.point end
function turtle.getState()   return state end
function turtle.isAborted()  return state.abort end
function turtle.getStatus()  return state.status end
function turtle.setStatus(s) state.status = s end

local function _defaultMove(action)
	while not action.move() do
		if not state.digPolicy(action) and not state.attackPolicy(action) then
			return false
		end
	end
	return true
end

function turtle.setPoint(pt, isGPS)
	turtle.point.x = pt.x
	turtle.point.y = pt.y
	turtle.point.z = pt.z
	if pt.heading then
		turtle.point.heading = pt.heading
	end
	turtle.point.gps = isGPS
	return true
end

function turtle.resetState()
	state.abort = false
	state.status = 'idle'
	state.attackPolicy = noop
	state.digPolicy = noop
	state.movePolicy = _defaultMove
	state.moveCallback = noop
	Pathing.reset()
	return true
end

function turtle.reset()
	turtle.point.x = 0
	turtle.point.y = 0
	turtle.point.z = 0
	turtle.point.heading = 0 -- should be facing
	turtle.point.gps = false

	turtle.resetState()
	return true
end

turtle.reset()

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

function turtle.getHeadingInfo(heading)
	heading = heading or turtle.point.heading
	return headings[heading]
end

-- hackish way to support unlimited fuel
if type(turtle.getFuelLevel()) ~= 'number' then
	function turtle.getFuelLevel()
		return 10000000
	end
end

-- [[ Basic turtle actions ]] --
local function inventoryAction(fn, name, qty)
	local slots = turtle.getFilledSlots()
	local s
	for _,slot in pairs(slots) do
		if slot.key == name or slot.name == name then
			turtle.native.select(slot.index)
			if not qty then
				s = fn()
			else
				s = fn(math.min(qty, slot.count))
				qty = qty - slot.count
				if qty < 0 then
					break
				end
			end
		end
	end
	if not s then
		return false, 'No items found'
	end
	return s
end

-- [[ Attack ]] --
local function _attack(action)
	if action.attack() then
		repeat until not action.attack()
		return true
	end
	return false
end

turtle.attackPolicies = {
	none = noop,

	attack = function(action)
		return _attack(action)
	end,
}

function turtle.attack()        return _attack(actions.forward) end
function turtle.attackUp()      return _attack(actions.up)      end
function turtle.attackDown()    return _attack(actions.down)    end

function turtle.setAttackPolicy(policy)  state.attackPolicy = policy end

-- [[ Place ]] --
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
		if not state.digPolicy(action) then
			state.attackPolicy(action)
		end
		return unpack(result)
	end)
end

function turtle.place(slot)     return _place(actions.forward, slot) end
function turtle.placeUp(slot)   return _place(actions.up, slot)      end
function turtle.placeDown(slot) return _place(actions.down, slot)    end

local function _drop(action, qtyOrName, qty)
	if not qtyOrName or type(qtyOrName) == 'number' then
		return action.drop(qtyOrName or 64)
	end
	return inventoryAction(action.drop, qtyOrName, qty)
end

function turtle.drop(count, slot)     return _drop(actions.forward, count, slot) end
function turtle.dropUp(count, slot)   return _drop(actions.up, count, slot)      end
function turtle.dropDown(count, slot) return _drop(actions.down, count, slot)    end

function turtle.refuel(qtyOrName, qty)
	if not qtyOrName or type(qtyOrName) == 'number' then
		return turtle.native.refuel(qtyOrName or 64)
	end
	return inventoryAction(turtle.native.refuel, qtyOrName, qty or 64)
end

function turtle.isTurtleAtSide(side)
	local sideType = peripheral.getType(side)
	return sideType and sideType == 'turtle'
end

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

turtle.movePolicies = {
	none = noop,
	default = _defaultMove,
	assured = function(action)
		if not _defaultMove(action) then
			if action.side == 'back' then
				return false
			end
			local oldStatus = state.status
			print('assured move: stuck')
			state.status = 'stuck'
			repeat
				os.sleep(1)
			until _defaultMove(action)
			state.status = oldStatus
		end
		return true
	end,
}

turtle.policies = {
	none        = { dig = turtle.digPolicies.none,        attack = turtle.attackPolicies.none },
	digOnly     = { dig = turtle.digPolicies.dig,         attack = turtle.attackPolicies.none },
	attackOnly  = { dig = turtle.digPolicies.none,        attack = turtle.attackPolicies.attack },
	digAttack   = { dig = turtle.digPolicies.dig,         attack = turtle.attackPolicies.attack },
	turtleSafe  = { dig = turtle.digPolicies.turtleSafe,  attack = turtle.attackPolicies.attack },

	attack      = { attack = turtle.attackPolicies.attack },

	defaultMove = { move = turtle.movePolicies.default },
	assuredMove = { move = turtle.movePolicies.assured },
}

function turtle.setPolicy(...)
	local args = { ... }
	for _, policy in pairs(args) do
		if type(policy) == 'string' then
			policy = turtle.policies[policy]
		end
		if not policy then
			error('Invalid policy')
			-- return false, 'Invalid policy'
		end
		if policy.dig then
			state.digPolicy = policy.dig
		end
		if policy.attack then
			state.attackPolicy = policy.attack
		end
		if policy.move then
			state.movePolicy = policy.move
		end
	end
	return true
end

function turtle.setDigPolicy(policy)     state.digPolicy = policy    end
function turtle.setMoveCallback(cb)      state.moveCallback = cb     end
function turtle.clearMoveCallback()      state.moveCallback = noop   end
function turtle.getMoveCallback()        return state.moveCallback   end

-- [[ Heading ]] --
function turtle.getHeading()
	return turtle.point.heading
end

function turtle.turnRight()
	turtle.setHeading((turtle.point.heading + 1) % 4)
	return turtle.point
end

function turtle.turnLeft()
	turtle.setHeading((turtle.point.heading - 1) % 4)
	return turtle.point
end

function turtle.turnAround()
	turtle.setHeading((turtle.point.heading + 2) % 4)
	return turtle.point
end

function turtle.setHeading(heading)
	if not heading then
		return false, 'Invalid heading'
	end

	local fi = Point.facings[heading]
	if not fi then
		return false, 'Invalid heading'
	end

	heading = fi.heading % 4
	if heading ~= turtle.point.heading then
		while heading < turtle.point.heading do
			heading = heading + 4
		end
		if heading - turtle.point.heading == 3 then
			turtle.native.turnLeft()
			turtle.point.heading = (turtle.point.heading - 1) % 4
			state.moveCallback('turn', turtle.point)
		else
			local turns = heading - turtle.point.heading
			while turns > 0 do
				turns = turns - 1
				turtle.native.turnRight()
				turtle.point.heading = (turtle.point.heading + 1) % 4
				state.moveCallback('turn', turtle.point)
			end
		end
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
function turtle.up()
	if state.movePolicy(actions.up) then
		turtle.point.y = turtle.point.y + 1
		state.moveCallback('up', turtle.point)
		return true, turtle.point
	end
end

function turtle.down()
	if state.movePolicy(actions.down) then
		turtle.point.y = turtle.point.y - 1
		state.moveCallback('down', turtle.point)
		return true, turtle.point
	end
end

function turtle.forward()
	if state.movePolicy(actions.forward) then
		turtle.point.x = turtle.point.x + headings[turtle.point.heading].xd
		turtle.point.z = turtle.point.z + headings[turtle.point.heading].zd
		state.moveCallback('forward', turtle.point)
		return true, turtle.point
	end
end

function turtle.back()
	if state.movePolicy(actions.back) then
		turtle.point.x = turtle.point.x - headings[turtle.point.heading].xd
		turtle.point.z = turtle.point.z - headings[turtle.point.heading].zd
		state.moveCallback('back', turtle.point)
		return true, turtle.point
	end
end

local function moveTowardsX(dx)
	if not tonumber(dx) then error('moveTowardsX: Invalid arguments') end
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

local function moveTowardsZ(dz)
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
function turtle.gotoSingleTurn(dx, dy, dz, dh)
	dx = dx or turtle.point.x
	dy = dy or turtle.point.y
	dz = dz or turtle.point.z

	local function gx()
		if turtle.point.x ~= dx then
			moveTowardsX(dx)
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
			moveTowardsZ(dz)
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

local function gotoEx(dx, dy, dz)
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
local function gotoMultiTurn(dx, dy, dz)
	if gotoEx(dx, dy, dz) then
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

		if gotoEx(dx, dy, dz) then
			return true
		end

		if dy then
			turtle.gotoY(dy)
		end

		moved = x ~= turtle.point.x or y ~= turtle.point.y or z ~= turtle.point.z
	until not moved

	return false
end

-- go backwards - turning around if necessary to fight mobs / break blocks
function turtle.goback()
	local hi = headings[turtle.point.heading]
	return turtle._goto({
		x = turtle.point.x - hi.xd,
		y = turtle.point.y,
		z = turtle.point.z - hi.zd,
		heading = turtle.point.heading,
	})
end

function turtle.gotoYfirst(pt)
	if turtle._gotoY(pt.y) then
		if turtle._goto(pt) then
			turtle.setHeading(pt.heading)
			return true
		end
	end
end

function turtle.gotoYlast(pt)
	if turtle._goto({ x = pt.x, z = pt.z, heading = pt.heading }) then
		if turtle.gotoY(pt.y) then
			turtle.setHeading(pt.heading)
			return true
		end
	end
end

function turtle._goto(pt)
	local dx, dy, dz, dh = pt.x, pt.y, pt.z, pt.heading
	if not turtle.gotoSingleTurn(dx, dy, dz, dh) then
		if not gotoMultiTurn(dx, dy, dz) then
			return false, 'Failed to reach location'
		end
	end
	turtle.setHeading(dh)
	return pt
end

-- avoid lint errors
turtle['goto'] = turtle._goto

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
			name = detail.name,
			damage = detail.damage,
			count = detail.count,
			key = detail.name .. ':' .. detail.damage,

			index = indexOrId,

			-- deprecate
			qty = detail.count,
			dmg = detail.damage,
			id = detail.name,
			iddmg = detail.name .. ':' .. detail.damage,
		}
	end

	-- inconsistent return value
	-- null is returned if indexOrId is a string and no item is present
	return {
		qty = 0,  -- deprecate
		count = 0,
		index = indexOrId,
	}
end

function turtle.select(indexOrId)
	if type(indexOrId) == 'number' then
		return turtle.native.select(indexOrId)
	end

	local s = turtle.getSlot(indexOrId)
	if s then
		turtle.native.select(s.index)
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

function turtle.getSummedInventory()
	local slots = turtle.getFilledSlots()
	local t = { }
	for _,slot in pairs(slots) do
		local entry = t[slot.iddmg]
		if not entry then
			entry = {
				count = 0,
				damage = slot.damage,
				name = slot.name,
				key = slot.key,

				-- deprecate
				qty = 0,
				dmg = slot.dmg,
				id = slot.id,
				iddmg = slot.iddmg,
			}
			t[slot.iddmg] = entry
		end
		entry.qty = entry.qty + slot.qty
		entry.count = entry.qty
	end
	return t
end

function turtle.has(item, count)
	if item:match('.*:%d') then
		local slot = turtle.getSummedInventory()[item]
		return slot and slot.count >= (count or 1)
	end
	local slot = turtle.getSlot(item)
	return slot and slot.count > 0
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

function turtle.emptyInventory(dropAction)
	dropAction = dropAction or turtle.native.drop
	turtle.eachFilledSlot(function(slot)
		turtle.select(slot.index)
		dropAction()
	end)
	turtle.select(1)
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

function turtle.selectSlotWithQuantity(qty, startSlot)
	startSlot = startSlot or 1

	for i = startSlot, 16 do
		if turtle.getItemCount(i) == qty then
			turtle.select(i)
			return i
		end
	end
end

function turtle.selectOpenSlot(startSlot)
	return turtle.selectSlotWithQuantity(0, startSlot)
end

function turtle.condense()
	local slots = turtle.getInventory()

	for i = 16, 1, -1 do
		if slots[i].count > 0 then
			for j = 1, i - 1 do
				if slots[j].count == 0 or slots[i].key == slots[j].key then
					turtle.select(i)
					turtle.transferTo(j, 64)
					local transferred = slots[i].qty - turtle.getItemCount(i)
					slots[j].count = slots[j].count + transferred
					slots[i].count = slots[i].count - transferred
					slots[j].key = slots[i].key
					if slots[i].count == 0 then
						break
					end
				end
			end
		end
	end
	return true
end

function turtle.getItemCount(idOrName)
	if type(idOrName) == 'number' then
		return turtle.native.getItemCount(idOrName)
	end
	local slots = turtle.getFilledSlots()
	local count = 0
	for _,slot in pairs(slots) do
		if slot.iddmg == idOrName or slot.name == idOrName then
			count = count + slot.qty
		end
	end
	return count
end

function turtle.equip(side, item)
	if item then
		if not turtle.select(item) then
			return false, 'Unable to equip ' .. item
		end
	end

	if side == 'left' then
		return turtle.equipLeft()
	end
	return turtle.equipRight()
end

function turtle.isEquipped(item)
	if peripheral.getType('left') == item then
		return 'left'
	elseif peripheral.getType('right') == item then
		return 'right'
	end
end

-- [[  ]] --
function turtle.run(fn, ...)
	local args = { ... }
	local s, m

	if type(fn) == 'string' then
		fn = turtle[fn]
	end

	synchronized(turtle, function()
		turtle.resetState()
		s, m = pcall(function() fn(unpack(args)) end)
		turtle.resetState()
		if not s and m then
			_G.printError(m)
		end
	end)

	return s, m
end

function turtle.abort(abort)
	state.abort = abort
	if abort then
		os.queueEvent('turtle_abort')
	end
end

-- [[ Pathing ]] --
function turtle.setPersistent(isPersistent)
	if isPersistent then
		Pathing.setBlocks({ })
	else
		Pathing.setBlocks()
	end
end

function turtle.setPathingBox(box)
	Pathing.setBox(box)
end

function turtle.addWorldBlock(pt)
	Pathing.addBlock(pt)
end

local movementStrategy = turtle.pathfind

function turtle.setMovementStrategy(strategy)
	if strategy == 'pathing' then
		movementStrategy = turtle.pathfind
	elseif strategy == 'goto' then
		movementStrategy = turtle._goto
	else
		error('Invalid movement strategy')
	end
end

function turtle.faceAgainst(pt, options) -- 4 sided
	options = options or { }
	options.dest = { }

	for i = 0, 3 do
		local hi = Point.facings[i]
		table.insert(options.dest, {
			x = pt.x + hi.xd,
			z = pt.z + hi.zd,
			y = pt.y + hi.yd,
			heading = (hi.heading + 2) % 4,
		})
	end

	return movementStrategy(Point.closest(turtle.point, options.dest), options)
end

-- move against this point
-- if the point does not contain a heading, then the turtle
-- will face the block (if on same plane)
-- if above or below, the heading is undetermined unless specified
function turtle.moveAgainst(pt, options) -- 6 sided
	options = options or { }
	options.dest = { }

	for i = 0, 5 do
		local hi = turtle.getHeadingInfo(i)
		local heading, direction
		if i < 4 then
			heading = (hi.heading + 2) % 4
			direction = 'forward'
		elseif i == 4 then
			direction = 'down'
		elseif i == 5 then
			direction = 'up'
		end

		table.insert(options.dest, {
			x = pt.x + hi.xd,
			z = pt.z + hi.zd,
			y = pt.y + hi.yd,
			direction = direction,
			heading = pt.heading or heading,
		})
	end

	return movementStrategy(Point.closest(turtle.point, options.dest), options)
end

local actionsAt = {
	detect = {
		up = turtle.detectUp,
		down = turtle.detectDown,
		forward = turtle.detect,
	},
	dig = {
		up = turtle.digUp,
		down = turtle.digDown,
		forward = turtle.dig,
	},
	move = {
		up = turtle.moveUp,
		down = turtle.moveDown,
		forward = turtle.move,
	},
	attack = {
		up = turtle.attackUp,
		down = turtle.attackDown,
		forward = turtle.attack,
	},
	place = {
		up = turtle.placeUp,
		down = turtle.placeDown,
		forward = turtle.place,
	},
	drop = {
		up = turtle.dropUp,
		down = turtle.dropDown,
		forward = turtle.drop,
	},
	suck = {
		up = turtle.suckUp,
		down = turtle.suckDown,
		forward = turtle.suck,
	},
	compare = {
		up = turtle.compareUp,
		down = turtle.compareDown,
		forward = turtle.compare,
	},
	inspect = {
		up = turtle.inspectUp,
		down = turtle.inspectDown,
		forward = turtle.inspect,
	},
}

-- pt = { x,y,z,heading,direction }
-- direction should only be up or down if provided
-- heading can be provided to tell which way to face during action
-- ex: place a block at the point from above facing east
local function _actionAt(action, pt, ...)
	if not pt.heading and not pt.direction then
		local msg
		pt, msg = turtle.moveAgainst(pt)
		if pt then
			return action[pt.direction](...)
		end
		return pt, msg
	end

	local reversed =
		{ [0] = 2, [1] = 3, [2] = 0, [3] = 1, [4] = 5, [5] = 4, }
	local dir = reversed[headings[pt.direction or pt.heading].heading]
	local apt = { x = pt.x + headings[dir].xd,
								y = pt.y + headings[dir].yd,
								z = pt.z + headings[dir].zd, }
	local direction

	-- ex: place a block at this point, from above, facing east
	if dir < 4 then
		apt.heading = (dir + 2) % 4
		direction = 'forward'
	elseif dir == 4 then
		apt.heading = pt.heading
		direction = 'down'
	elseif dir == 5 then
		apt.heading = pt.heading
		direction = 'up'
	end

	if movementStrategy(apt) then
		return action[direction](...)
	end
end

local function _actionDownAt(action, pt, ...)
	pt = Util.shallowCopy(pt)
	pt.direction = Point.DOWN
	return _actionAt(action, pt, ...)
end

local function _actionUpAt(action, pt, ...)
	pt = Util.shallowCopy(pt)
	pt.direction = Point.UP
	return _actionAt(action, pt, ...)
end

local function _actionForwardAt(action, pt, ...)
	if turtle.faceAgainst(pt) then
		return action.forward(...)
	end
end

function turtle.detectAt(pt)             return _actionAt(actionsAt.detect, pt) end
function turtle.detectDownAt(pt)         return _actionDownAt(actionsAt.detect, pt) end
function turtle.detectForwardAt(pt)      return _actionForwardAt(actionsAt.detect, pt) end
function turtle.detectUpAt(pt)           return _actionUpAt(actionsAt.detect, pt) end

function turtle.digAt(pt)                return _actionAt(actionsAt.dig, pt) end
function turtle.digDownAt(pt)            return _actionDownAt(actionsAt.dig, pt) end
function turtle.digForwardAt(pt)         return _actionForwardAt(actionsAt.dig, pt) end
function turtle.digUpAt(pt)              return _actionUpAt(actionsAt.dig, pt) end

function turtle.attackAt(pt)             return _actionAt(actionsAt.attack, pt) end
function turtle.attackDownAt(pt)         return _actionDownAt(actionsAt.attack, pt) end
function turtle.attackForwardAt(pt)      return _actionForwardAt(actionsAt.attack, pt) end
function turtle.attackUpAt(pt)           return _actionUpAt(actionsAt.attack, pt) end

function turtle.placeAt(pt, arg, dir)    return _actionAt(actionsAt.place, pt, arg, dir) end
function turtle.placeDownAt(pt, arg)     return _actionDownAt(actionsAt.place, pt, arg) end
function turtle.placeForwardAt(pt, arg)  return _actionForwardAt(actionsAt.place, pt, arg) end
function turtle.placeUpAt(pt, arg)       return _actionUpAt(actionsAt.place, pt, arg) end

function turtle.dropAt(pt, ...)          return _actionAt(actionsAt.drop, pt, ...) end
function turtle.dropDownAt(pt, ...)      return _actionDownAt(actionsAt.drop, pt, ...) end
function turtle.dropForwardAt(pt, ...)   return _actionForwardAt(actionsAt.drop, pt, ...) end
function turtle.dropUpAt(pt, ...)        return _actionUpAt(actionsAt.drop, pt, ...) end

function turtle.suckAt(pt, qty)          return _actionAt(actionsAt.suck, pt, qty or 64) end
function turtle.suckDownAt(pt, qty)      return _actionDownAt(actionsAt.suck, pt, qty or 64) end
function turtle.suckForwardAt(pt, qty)   return _actionForwardAt(actionsAt.suck, pt, qty or 64) end
function turtle.suckUpAt(pt, qty)        return _actionUpAt(actionsAt.suck, pt, qty or 64) end

function turtle.compareAt(pt)            return _actionAt(actionsAt.compare, pt) end
function turtle.compareDownAt(pt)        return _actionDownAt(actionsAt.compare, pt) end
function turtle.compareForwardAt(pt)     return _actionForwardAt(actionsAt.compare, pt) end
function turtle.compareUpAt(pt)          return _actionUpAt(actionsAt.compare, pt) end

function turtle.inspectAt(pt)            return _actionAt(actionsAt.inspect, pt) end
function turtle.inspectDownAt(pt)        return _actionDownAt(actionsAt.inspect, pt) end
function turtle.inspectForwardAt(pt)     return _actionForwardAt(actionsAt.inspect, pt) end
function turtle.inspectUpAt(pt)          return _actionUpAt(actionsAt.inspect, pt) end

-- [[ GPS ]] --
function turtle.enableGPS(timeout)
	local pt = GPS.getPointAndHeading(timeout)
	if pt then
		turtle.setPoint(pt, true)
		return turtle.point
	end
end

function turtle.addFeatures(...)
	for _,feature in pairs({ ... }) do
		require('turtle.' .. feature)
	end
end

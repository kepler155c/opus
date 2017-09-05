requireInjector(getfenv(1))

local Event      = require('event')
local Logger     = require('logger')
local MEProvider = require('meProvider')
local Message    = require('message')
local Point      = require('point')
local TableDB    = require('tableDB')
local Util       = require('util')

--[[
  A supplier turtle for the builder turtle. For larger builds, use
  ender modems.

  Setup:

  1. chest or ME interface at level 0 (bottom of build area)
  2. builder turtle on top facing the build area
  3. If facing the build turtle, the supplier turtle is to the right
     pointing at the chest/interface
]]--

local ChestProvider = require('chestProvider')
if Util.getVersion() == 1.8 then
  ChestProvider = require('chestProvider18')
end

if not device.wireless_modem then
	error('No wireless modem detected')
end

Logger.filter('modem_send', 'event', 'ui')
Logger.setWirelessLogging()

local __BUILDER_ID = 6
local itemInfoDB

local Builder = {
  version = '1.70',
  ccVersion = nil,
  slots = { },
  index = 1,
  fuelItem = { id = 'minecraft:coal', dmg = 0 },
  resupplying = true,
  ready = true,
}

--[[-- maxStackDB --]]--
local maxStackDB = TableDB({
  fileName = 'maxstack.db',
  tabledef = {
    autokeys = false,
    type = 'simple',
    columns = {
      { label = 'Key', type = 'key', length = 8 },
      { label = 'Quantity', type = 'number', length = 2 }
    }
  }
})
 
function maxStackDB:get(id, dmg)
  return self.data[id .. ':' .. dmg] or 64
end

function Builder:dumpInventory()

  local success = true

  for i = 1, 16 do
    local qty = turtle.getItemCount(i)
    if qty > 0 then
      self.itemProvider:insert(i, qty)
    end
    if turtle.getItemCount(i) ~= 0 then
      success = false
    end
  end
  turtle.select(1)

  return success
end

function Builder:dumpInventoryWithCheck()
  while not self:dumpInventory() do
    Builder:log('Unable to dump inventory')
    print('Provider is full or missing - make space or replace')
    print('Press enter to continue')
    --turtle.setHeading(0)
    self.ready = false
    read()
  end
  self.ready = true
end

function Builder:autocraft(supplies)
  local t = { }

  for i,s in pairs(supplies) do
    local key = s.id .. ':' .. s.dmg
    local item = t[key]
    if not item then
      item = {
        id = s.id,
        dmg = s.dmg,
        qty = 0,
      }
      t[key] = item
    end
    item.qty = item.qty + (s.need-s.qty)
  end
 
  Builder.itemProvider:craftItems(t)
end

function Builder:refuel()
  while turtle.getFuelLevel() < 4000 and self.fuelItem do
    Builder:log('Refueling')
    turtle.select(1)
    self.itemProvider:provide(self.fuelItem, 64, 1)
    if turtle.getItemCount(1) == 0 then
      Builder:log('Out of fuel, add coal to chest/ME system')
      --turtle.setHeading(0)
      os.sleep(5)
    else
      turtle.refuel(64)
    end
  end
end

function Builder:log(...)
  Logger.log('supplier', ...)
  Util.print(...)
end

function Builder:getSupplies()
 
  Builder.itemProvider:refresh()
 
  local t = { }
  for _,s in ipairs(self.slots) do
    if s.need > 0 then
      local item = Builder.itemProvider:getItemInfo(s.id, s.dmg)
      if item then
        if item.name then
          s.name = item.name
        end

        local qty = math.min(s.need-s.qty, item.qty)

        if qty + s.qty > item.max_size then
          maxStackDB:add({ s.id, s.dmg }, item.max_size)
          maxStackDB.dirty = true
          maxStackDB:flush()
          qty = item.max_size
          s.need = qty
        end
        if qty > 0 then
          self.itemProvider:provide(item, qty, s.index)
          s.qty = turtle.getItemCount(s.index)
        end
      end
    end
    if s.qty < s.need then
      table.insert(t, s)
      local name = s.name or s.id .. ':' .. s.dmg
      local item = itemInfoDB:get({ s.id, s.dmg })
      if item then
        name = item.displayName
      end

      Builder:log('Need %d %s', s.need - s.qty, name)
    end
  end
 
  return t
end

local function moveTowardsX(dx)

  local direction = dx - turtle.point.x
  local move
  
  if direction == 0 then
    return false
  end
  
  if direction > 0 and turtle.point.heading == 0 or
     direction < 0 and turtle.point.heading == 2 then
    move = turtle.forward
  else
    move = turtle.back
  end

  return move()
end

local function moveTowardsZ(dz)

  local direction = dz - turtle.point.z
  local move

  if direction == 0 then
    return false
  end
  
  if direction > 0 and turtle.point.heading == 1 or
     direction < 0 and turtle.point.heading == 3 then
    move = turtle.forward
  else
    move = turtle.back
  end

  return move()
end

function Builder:finish()

  Builder.resupplying = true
  Builder.ready = false
  if turtle.gotoLocation('supplies') then
    turtle.setHeading(1)
    os.sleep(.1) -- random 'Computer is not connected' error...
    Builder:dumpInventory()
    Event.exitPullEvents()
    print('Finished')
  end
end

function Builder:gotoBuilder()

	if Builder.lastPoint then
    turtle.status = 'tracking'
		while true do
			local pt = Point.copy(Builder.lastPoint)
			pt.y = pt.y + 3
			if turtle.point.y ~= pt.y then
				turtle.gotoY(pt.y)
			else
				local distance = Point.turtleDistance(turtle.point, pt)
				if distance <= 3 then
					Builder:log('Synchronized')
					break
				end

				if turtle.point.heading % 2 == 0 then
					if turtle.point.x == pt.x then
						turtle.headTowardsZ(pt.z)
						moveTowardsZ(pt.z)
					else
						moveTowardsX(pt.x)
					end
				elseif turtle.point.z ~= pt.z then
					moveTowardsZ(pt.z)
				else
					turtle.headTowardsX(pt.x)
					moveTowardsX(pt.x)
				end
			end
		end
	end
end

Message.addHandler('builder', 
  function(h, id, msg, distance)
  	if not id or id ~= __BUILDER_ID then
  		return
  	end

    if not Builder.resupplying then
    	local pt = msg.contents
    	pt.y = pt.y + 3

      turtle.status = 'supervising'
  		turtle.gotoYfirst(pt)
  	end
  end)

Message.addHandler('supplyList', 
  function(h, id, msg, distance)
  	if not id or id ~= __BUILDER_ID then
  		return
  	end

    turtle.status = 'resupplying'
  	Builder.resupplying = true
  	Builder.slots = msg.contents.slots
  	Builder.slotUid = msg.contents.uid

    Builder:log('Received supply list ' .. Builder.slotUid)

  	os.sleep(0)
  	if not turtle.gotoLocation('supplies') then
  		Builder:log('Failed to go to supply location')
  		self.ready = false
  		Event.exitPullEvents()
  	end
    turtle.setHeading(1)
    os.sleep(.2) -- random 'Computer is not connected' error...
    Builder:dumpInventoryWithCheck()
    Builder:refuel()

    while true do
  	  local supplies = Builder:getSupplies()
  	  if #supplies == 0 then
  	  	break
  	  end
  	  Builder:autocraft(supplies)
      turtle.status = 'waiting'
  	  os.sleep(5)
  	end
  	Builder:log('Got all supplies')
  	os.sleep(0)
  	Builder:gotoBuilder()
  	Builder.resupplying = false
  end)

Message.addHandler('needSupplies', 
  function(h, id, msg, distance)
  	if not id or id ~= __BUILDER_ID then
  		return
  	end

  	if Builder.resupplying or msg.contents.uid ~= Builder.slotUid then
  		
  		Builder:log('No supplies ready')

  		Message.send(__BUILDER_ID, 'gotSupplies')
  	else
      turtle.status = 'supplying'
  		Builder:log('Supplying')
  		os.sleep(0)

  		local pt = msg.contents.point
  		pt.y = turtle.getPoint().y
  		pt.heading = nil
  		if not turtle.gotoYfirst(pt) then -- location of builder
  			Builder.resupplying = true
	  		Message.send(__BUILDER_ID, 'gotSupplies')
  		  os.sleep(0)
  			if not turtle.gotoLocation('supplies') then
  				Builder:log('failed to go to supply location')
  				--self.ready = false
  				Event.exitPullEvents()
  			end
        turtle.setHeading(1)
	  		return
  		end
  		pt.y = pt.y - 2 -- location where builder should go for the chest to be above

	  	turtle.select(15)
  		turtle.placeDown()
  		os.sleep(.1) -- random computer not connected error
      local p = ChestProvider({ direction = 'up', wrapSide = 'bottom' })
  		for i = 1, 16 do
  			p:insert(i, 64)
  		end

  		Message.send(__BUILDER_ID, 'gotSupplies', { supplies = true, point = pt })

  		Message.waitForMessage('thanks', 5, __BUILDER_ID)
  		--os.sleep(0)

  		--p.condenseItems()
  		for i = 1, 16 do
  			p:extract(i, 64)
  		end
    	turtle.digDown()
      turtle.status = 'waiting'
  	end
  end)

Message.addHandler('finished',
  function(h, id)
  	if not id or id ~= __BUILDER_ID then
  		return
  	end
    Builder:finish()
  end)

Event.on('turtle_abort',
  function()
    turtle.abort = false
    turtle.status = 'aborting'
    Builder:finish()
  end)

local function onTheWay() -- parallel routine
  while true do
	  local e, side, _id, id, msg, distance = os.pullEvent('modem_message')
	  if Builder.ready then
      if id == __BUILDER_ID and msg and msg.type then
      	if msg.type == 'needSupplies' then
      	  Message.send(__BUILDER_ID, 'gotSupplies', { supplies = true })
      	elseif msg.type == 'builder' then
   		    Builder.lastPoint = msg.contents
      	end
      end
    end
  end
end

local args = {...}
if #args < 2 then
  error('syntax: <builder id> <facing>')
end

__BUILDER_ID = tonumber(args[1])

maxStackDB:load()

itemInfoDB = TableDB({
  fileName = 'items.db'
})

itemInfoDB:load()

Builder.itemProvider = MEProvider({ direction = args[2] })
if not Builder.itemProvider:isValid() then
  local sides = {
    east = 'west',
    west = 'east',
    north = 'south',
    south = 'north',
  }

  Builder.itemProvider = ChestProvider({ direction = sides[args[2]], wrapSide = 'front' })
  if not Builder.itemProvider:isValid() then
    error('A chest or ME interface must be in front of turtle')
  end
end

turtle.run(function()
  turtle.setPoint({ x = -1, z = -2, y = -1, heading = 1 })

  turtle.saveLocation('supplies')

  Event.pullEvents(onTheWay)
end)

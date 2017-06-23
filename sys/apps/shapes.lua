require = requireInjector(getfenv(1))
local UI = require('ui')
local GPS = require('gps')
local Socket = require('socket')

multishell.setTitle(multishell.getCurrent(), 'Shapes')

local args = { ... }
local turtleId = args[1] or error('Supply turtle ID')
turtleId = tonumber(turtleId)

local script = [[

require = requireInjector(getfenv(1))
local GPS = require('gps')
local ChestProvider = require('chestProvider18')
local Point = require('point')

local itemProvider

function dumpInventory()

  for i = 1, 16 do
    local qty = turtle.getItemCount(i)
    if qty > 0 then
      itemProvider:insert(i, qty)
    end
    if turtle.getItemCount(i) ~= 0 then
      print('Provider is full or missing - make space or replace')
      print('Press enter to continue')
      read()
    end
  end
  turtle.select(1)
end

local function refuel()
  while turtle.getFuelLevel() < 4000 do
    print('Refueling')
    turtle.select(1)

    itemProvider:provide({ id = 'minecraft:coal', dmg = 0 }, 64, 1)
    if turtle.getItemCount(1) == 0 then
      print('Out of fuel, add fuel to chest/ME system')
      turtle.status = 'waiting'
      os.sleep(5)
    else
      turtle.refuel(64)
    end
  end
end

local function goto(pt)
  while not turtle.gotoPoint(pt) do
    print('stuck')
    os.sleep(5)
  end
end

local function pathTo(pt)
  while not turtle.pathfind(pt) do
    print('stuck')
    os.sleep(5)
  end
end

local function resupply()

  if data.suppliesPt then
    pathTo(data.suppliesPt)

    itemProvider = ChestProvider({ direction = 'up', wrapSide = 'bottom' })
    dumpInventory()
    refuel()
  end
end

local function makePlane(y)
  local pt = { x  = math.min(data.startPt.x, data.endPt.x), 
               ex = math.max(data.startPt.x, data.endPt.x),
               z  = math.min(data.startPt.z, data.endPt.z), 
               ez = math.max(data.startPt.z, data.endPt.z) }

  local blocks = { }
  for z = pt.z, pt.ez do
    for x = pt.x, pt.ex do
      table.insert(blocks, { x = x, y = y, z = z })
    end
  end

  return blocks
end

local function optimizeRoute(plane, ptb)

  local maxDistance = 99999999
 
  local function getNearestNeighbor(p, pt, threshold)
    local key, block, heading
    local moves = maxDistance

    local function getMoves(b, k)
      local distance = math.abs(pt.x - b.x) + math.abs(pt.z - b.z)

      if distance < moves then
        -- this operation is expensive - only run if distance is close
        local c, h = Point.calculateMoves(pt, b, distance)
        if c < moves then
          block = b
          key = k
          moves = c
          heading = h
        end
      end
    end

    local function blockReady(b)
      return not b.u
    end

    local mid = pt.index
    local forward = mid + 1
    local backward = mid - 1
    while forward <= #p or backward > 0 do
      if forward <= #p then
        local b = p[forward]
        if blockReady(b) then
          getMoves(b, forward)
          if moves <= threshold then
            break
          end
          if moves < maxDistance and math.abs(b.z - pt.z) > moves and pt.index > 0 then
            forward = #p
          end
        end
        forward = forward + 1
      end
      if backward > 0 then
        local b = p[backward]
        if blockReady(b) then
          getMoves(b, backward)
          if moves <= threshold then
            break
          end
          if moves < maxDistance and math.abs(pt.z - b.z) > moves then
            backward = 0
          end
        end
        backward = backward - 1
      end
    end
    pt.x = block.x
    pt.z = block.z
    pt.y = block.y
    pt.heading = heading
    pt.index = key
    block.u = true
    return block
  end

  local throttle = Util.throttle()
  local t = { }
  ptb.index = 0
  local threshold = 0
  for i = 1, #plane do
    local b = getNearestNeighbor(plane, ptb, threshold)
    table.insert(t, b)
    throttle()
    threshold = 1
  end

  return t
end

local function clear()

  local pt = Util.shallowCopy(data.startPt)
  pt.y = math.min(data.startPt.y, data.endPt.y)
  pt.heading = 0

  local osy = pt.y
  local sy = osy + 1
  local ey = math.max(data.startPt.y, data.endPt.y)
  local firstPlane = true

  resupply()

  while true do

    if sy > ey then
      sy = ey
    end

    local plane = makePlane(sy)
    plane = optimizeRoute(plane, pt)

    if firstPlane then
      turtle.pathfind(plane[1])
      turtle.setPolicy(turtle.policies.digAttack)
      firstPlane = false
    end

    for _,b in ipairs(plane) do
      turtle.gotoPoint(b)
      if sy < ey then
        turtle.digUp()
      end
      if sy > osy then
        turtle.digDown()
      end
      if turtle.abort then
        break
      end
    end

    if turtle.abort then
      break
    end
    if sy + 1 >= ey then
      break
    end

    sy = sy + 3
  end
  turtle.setPolicy(turtle.policies.none)
  resupply()
end

turtle.run(function()
  turtle.status = 'Clearing'

  if turtle.enableGPS() then

    local pt = Util.shallowCopy(turtle.point)
    local s, m = pcall(clear)
    pathTo(pt)

    if not s and m then
      error(m)
      read()
    end
  end
end)
]]

local data = Util.readTable('/usr/config/shapes') or { }

local page = UI.Page {
  titleBar   = UI.TitleBar { title = 'Shapes' },
  info       = UI.Window {  x =  5,  y =  3, height = 1 },
  startCoord = UI.Button {  x =  2,  y =  6, text = 'Start   ', event = 'startCoord' },
  endCoord   = UI.Button {  x =  2,  y =  8, text = 'End     ', event = 'endCoord'   },
  supplies   = UI.Button {  x =  2,  y = 10, text = 'Supplies', event = 'supplies'   },
  cancel     = UI.Button { rx =  2, ry = -2, text = 'Abort',    event = 'cancel'     },
  begin      = UI.Button { rx = -7, ry = -2, text = 'Begin',    event = 'begin'      },
  accelerators = { q = 'quit' },
  notification = UI.Notification(),
  statusBar = UI.StatusBar(),
}

function page.info:draw()

  local function size(a, b)
    return (math.abs(a.x - b.x) + 1) *
           (math.abs(a.y - b.y) + 1) *
           (math.abs(a.z - b.z) + 1)
  end

  self:clear()
  if not data.startPt then
    self:write(1, 1, 'Set starting corner')
  elseif not data.endPt then
    self:write(1, 1, 'Set ending corner')
  else
    self:write(1, 1, 'Blocks: ' .. size(data.startPt, data.endPt))
  end
end

function page:getPoint()
  local pt = GPS.getPoint()
  if not pt then
    self.notification:error('GPS not available')
  end
  return pt
end

function page:runFunction(id, script)

  self.notification:info('Connecting')
  local fn, msg = loadstring(script, 'script')
  if not fn then
    self.notification:error('Error in script')
    debug(msg)
    return
  end

  local socket = Socket.connect(id, 161)
  if not socket then
    self.notification:error('Unable to connect')
    return
  end

  socket:write({ type = 'script', args = script })
  socket:close()

  self.notification:success('Sent')
end

function page:eventHandler(event)
  if event.type == 'startCoord' then
    data.startPt = self:getPoint()
    if data.startPt then
      self.statusBar:setStatus('starting corner set')
      Util.writeTable('/usr/config/shapes', data)
    end
    self:draw()
  elseif event.type == 'endCoord' then
    data.endPt = self:getPoint()
    if data.endPt then
      self.statusBar:setStatus('ending corner set')
      Util.writeTable('/usr/config/shapes', data)
    end
    self:draw()
  elseif event.type == 'supplies' then
    data.suppliesPt = self:getPoint()
    if data.suppliesPt then
      self.statusBar:setStatus('supplies location set')
      Util.writeTable('/usr/config/shapes', data)
    end
  elseif event.type == 'begin' then
    if data.startPt and data.endPt then
      local s = 'local data = ' .. textutils.serialize(data) .. script
      self:runFunction(turtleId, s)
    else
      self.notification:error('Corners not set')
    end
    self.statusBar:setStatus('')
  elseif event.type == 'cancel' then
    self:runFunction(turtleId, 'turtle.abortAction()')
    self.statusBar:setStatus('')
  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

UI:setPage(page)

UI:pullEvents()
UI.term:reset()

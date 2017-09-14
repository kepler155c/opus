local Point = require('point')
local Util  = require('util')

local checkedNodes = { }
local nodes = { }
local box = { }
local oldCallback

local function toKey(pt)
  return table.concat({ pt.x, pt.y, pt.z }, ':')
end

local function addNode(node)

  for i = 0, 5 do
    local hi = turtle.getHeadingInfo(i)
    local testNode = { x = node.x + hi.xd, y = node.y + hi.yd, z = node.z + hi.zd }

    if Point.inBox(testNode, box) then
      local key = toKey(testNode)
      if not checkedNodes[key] then
        nodes[key] = testNode
      end
    end
  end
end

local function dig(action)

  local directions = {
    top = 'up',
    bottom = 'down',
  }

  -- convert to up, down, north, south, east, west
  local direction = directions[action.side] or 
                    turtle.getHeadingInfo(turtle.point.heading).direction

  local hi = turtle.getHeadingInfo(direction)
  local node = { x = turtle.point.x + hi.xd, y = turtle.point.y + hi.yd, z = turtle.point.z + hi.zd }

  if Point.inBox(node, box) then

    local key = toKey(node)
    checkedNodes[key] = true
    nodes[key] = nil

    if action.dig() then
      addNode(node)
      repeat until not action.dig() -- sand, etc
      return true
    end
  end
end

local function move(action)
  if action == 'turn' then
    dig(turtle.getAction('forward'))
  elseif action == 'up' then
    dig(turtle.getAction('up'))
    dig(turtle.getAction('forward'))
  elseif action == 'down' then
    dig(turtle.getAction('down'))
    dig(turtle.getAction('forward'))
  elseif action == 'back' then
    dig(turtle.getAction('up'))
    dig(turtle.getAction('down'))
  end

  if oldCallback then
    oldCallback(action)
  end
end

-- find the closest block
-- * favor same plane
-- * going backwards only if the dest is above or below
function closestPoint(reference, pts)
  local lpt, lm -- lowest
  for _,pt in pairs(pts) do
    local m = Point.turtleDistance(reference, pt)
    local h = Point.calculateHeading(reference, pt)
    local t = Point.calculateTurns(reference.heading, h)
    if pt.y ~= reference.y then -- try and stay on same plane
      m = m + .01
    end
    if t ~= 2 or pt.y == reference.y then
      m = m + t
      if t > 0 then
        m = m + .01
      end
    end
    if not lm or m < lm then
      lpt = pt
      lm = m
    end
  end
  return lpt
end

local function getAdjacentPoint(pt)
  local t = { }
  table.insert(t, pt)
  for i = 0, 5 do
    local hi = turtle.getHeadingInfo(i)
    local heading
    if i < 4 then
      heading = (hi.heading + 2) % 4
    end
    table.insert(t, { x = pt.x + hi.xd, z = pt.z + hi.zd, y = pt.y + hi.yd, heading = heading })
  end

  return closestPoint(turtle.getPoint(), t)
end

return function(startPt, endPt, firstPt, verbose)

  checkedNodes = { }
  nodes = { }
  box = { }

  box.x = math.min(startPt.x, endPt.x)
  box.y = math.min(startPt.y, endPt.y)
  box.z = math.min(startPt.z, endPt.z)
  box.ex = math.max(startPt.x, endPt.x)
  box.ey = math.max(startPt.y, endPt.y)
  box.ez = math.max(startPt.z, endPt.z)

  if not turtle.pathfind(firstPt) then
    error('failed to reach starting point')
  end

  turtle.setPolicy("attack", { dig = dig }, "assuredMove")

  oldCallback = turtle.getMoveCallback()
  turtle.setMoveCallback(move)

  repeat
    local key = toKey(turtle.point)

    checkedNodes[key] = true
    nodes[key] = nil

    dig(turtle.getAction('down'))
    dig(turtle.getAction('up'))
    dig(turtle.getAction('forward'))

    if verbose then
      print(string.format('%d nodes remaining', Util.size(nodes)))
    end

    if Util.size(nodes) == 0 then
      break
    end

    local node = closestPoint(turtle.point, nodes)
    node = getAdjacentPoint(node)
    if not turtle.gotoPoint(node) then
      break
    end
  until turtle.abort

  turtle.resetState()
  turtle.setMoveCallback(oldCallback)
end

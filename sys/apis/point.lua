local Util = require('util')

local Point = { }

function Point.copy(pt)
  return { x = pt.x, y = pt.y, z = pt.z }
end

function Point.same(pta, ptb)
  return pta.x == ptb.x and
         pta.y == ptb.y and
         pta.z == ptb.z
end

function Point.above(pt)
  return { x = pt.x, y = pt.y + 1, z = pt.z, heading = pt.heading }
end

function Point.below(pt)
  return { x = pt.x, y = pt.y - 1, z = pt.z, heading = pt.heading }
end

function Point.subtract(a, b)
  a.x = a.x - b.x
  a.y = a.y - b.y
  a.z = a.z - b.z
end

-- Euclidian distance
function Point.pythagoreanDistance(a, b)
  return math.sqrt(
           math.pow(a.x - b.x, 2) +
           math.pow(a.y - b.y, 2) +
           math.pow(a.z - b.z, 2))
end

-- turtle distance (manhattan)
function Point.turtleDistance(a, b)
  if a.y and b.y then
    return math.abs(a.x - b.x) + 
           math.abs(a.y - b.y) +
           math.abs(a.z - b.z)
  else
    return math.abs(a.x - b.x) +
           math.abs(a.z - b.z)
  end
end

function Point.calculateTurns(ih, oh)
  if ih == oh then
    return 0
  end
  if (ih % 2) == (oh % 2) then
    return 2
  end
  return 1
end

function Point.calculateHeading(pta, ptb)

  local heading

  if (pta.heading % 2) == 0 and pta.z ~= ptb.z then
    if ptb.z > pta.z then
      heading = 1
    else
      heading = 3
    end
  elseif (pta.heading % 2) == 1 and pta.x ~= ptb.x then
    if ptb.x > pta.x then
      heading = 0
    else
      heading = 2
    end
  elseif pta.heading == 0 and pta.x > ptb.x then
    heading = 2
  elseif pta.heading == 2 and pta.x < ptb.x then
    heading = 0
  elseif pta.heading == 1 and pta.z > ptb.z then
    heading = 3
  elseif pta.heading == 3 and pta.z < ptb.z then
    heading = 1
  end

  return heading or pta.heading
end

-- Calculate distance to location including turns
-- also returns the resulting heading
function Point.calculateMoves(pta, ptb, distance)
  local heading = pta.heading
  local moves = distance or Point.turtleDistance(pta, ptb)
  if (pta.heading % 2) == 0 and pta.z ~= ptb.z then
    moves = moves + 1
    if ptb.heading and (ptb.heading % 2 == 1) then
      heading = ptb.heading
    elseif ptb.z > pta.z then
      heading = 1
    else
      heading = 3
    end
  elseif (pta.heading % 2) == 1 and pta.x ~= ptb.x then
    moves = moves + 1
    if ptb.heading and (ptb.heading % 2 == 0) then
      heading = ptb.heading
    elseif ptb.x > pta.x then
      heading = 0
    else
      heading = 2
    end
  end

  if ptb.heading then
    if heading ~= ptb.heading then
      moves = moves + Point.calculateTurns(heading, ptb.heading)
      heading = ptb.heading
    end
  end
  
  return moves, heading
end

-- given a set of points, find the one taking the least moves
function Point.closest(reference, pts)
  local lpt, lm -- lowest
  for _,pt in pairs(pts) do
    local m = Point.calculateMoves(reference, pt)
    if not lm or m < lm then
      lpt = pt
      lm = m
    end
  end
  return lpt
end

function Point.eachClosest(spt, ipts, fn)

  local pts = Util.shallowCopy(ipts)
  while #pts > 0 do
    local pt = Point.closest(spt, pts)
    local r = fn(pt)
    if r then
      return r
    end
    Util.removeByValue(pts, pt)
  end
end

function Point.adjacentPoints(pt)
  local pts = { }

  for _, hi in pairs(turtle.getHeadings()) do
    table.insert(pts, { x = pt.x + hi.xd, y = pt.y + hi.yd, z = pt.z + hi.zd })
  end

  return pts
end

function Point.normalizeBox(box)
  return {
    x = math.min(box.x, box.ex),
    y = math.min(box.y, box.ey),
    z = math.min(box.z, box.ez),
    ex = math.max(box.x, box.ex),
    ey = math.max(box.y, box.ey),
    ez = math.max(box.z, box.ez),
  }
end

function Point.inBox(pt, box)
  return pt.x >= box.x and
         pt.y >= box.y and
         pt.z >= box.z and
         pt.x <= box.ex and
         pt.z <= box.ez
end

return Point

--[[
Box = { }

function Box.contain(boundingBox, containedBox)

  local shiftX = boundingBox.ax - containedBox.ax
  if shiftX > 0 then
    containedBox.ax = containedBox.ax + shiftX
    containedBox.bx = containedBox.bx + shiftX
  end
  local shiftZ = boundingBox.az - containedBox.az
  if shiftZ > 0 then
    containedBox.az = containedBox.az + shiftZ
    containedBox.bz = containedBox.bz + shiftZ
  end

  shiftX = boundingBox.bx - containedBox.bx
  if shiftX < 0 then
    containedBox.ax = containedBox.ax + shiftX
    containedBox.bx = containedBox.bx + shiftX
  end
  shiftZ = boundingBox.bz - containedBox.bz
  if shiftZ < 0 then
    containedBox.az = containedBox.az + shiftZ
    containedBox.bz = containedBox.bz + shiftZ
  end
end
--]]
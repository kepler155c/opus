local Util = require('opus.util')

local Point = { }

Point.directions = {
	[ 0 ] = { xd =  1, zd =  0, yd =  0, heading = 0, direction = 'east'  },
	[ 1 ] = { xd =  0, zd =  1, yd =  0, heading = 1, direction = 'south' },
	[ 2 ] = { xd = -1, zd =  0, yd =  0, heading = 2, direction = 'west'  },
	[ 3 ] = { xd =  0, zd = -1, yd =  0, heading = 3, direction = 'north' },
	[ 4 ] = { xd =  0, zd =  0, yd =  1, heading = 4, direction = 'up'    },
	[ 5 ] = { xd =  0, zd =  0, yd = -1, heading = 5, direction = 'down'  },
}

Point.facings = {
	[ 0 ] = Point.directions[0],
	[ 1 ] = Point.directions[1],
	[ 2 ] = Point.directions[2],
	[ 3 ] = Point.directions[3],
	east  = Point.directions[0],
	south = Point.directions[1],
	west  = Point.directions[2],
	north = Point.directions[3],
}

Point.headings = {
	[ 0 ] = Point.directions[0],
	[ 1 ] = Point.directions[1],
	[ 2 ] = Point.directions[2],
	[ 3 ] = Point.directions[3],
	[ 4 ] = Point.directions[4],
	[ 5 ] = Point.directions[5],
	east  = Point.directions[0],
	south = Point.directions[1],
	west  = Point.directions[2],
	north = Point.directions[3],
	up    = Point.directions[4],
	down  = Point.directions[5],
}

Point.EAST  = 0
Point.SOUTH = 1
Point.WEST  = 2
Point.NORTH = 3
Point.UP    = 4
Point.DOWN  = 5

function Point.copy(pt)
	return { x = pt.x, y = pt.y, z = pt.z }
end

function Point.round(pt)
	pt.x = Util.round(pt.x)
	pt.y = Util.round(pt.y)
	pt.z = Util.round(pt.z)
	return pt
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
function Point.distance(a, b)
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
	local xd, zd = pta.x - ptb.x, pta.z - ptb.z

	if (pta.heading % 2) == 0 and zd ~= 0 then
		heading = zd < 0 and 1 or 3
	elseif (pta.heading % 2) == 1 and xd ~= 0 then
		heading = xd < 0 and 0 or 2
	elseif pta.heading == 0 and xd > 0 then
		heading = 2
	elseif pta.heading == 2 and xd < 0 then
		heading = 0
	elseif pta.heading == 1 and zd > 0 then
		heading = 3
	elseif pta.heading == 3 and zd < 0 then
		heading = 1
	end

	return heading or pta.heading
end

-- Calculate distance to location including turns
-- also returns the resulting heading
function Point.calculateMoves(pta, ptb, distance)
	local heading = pta.heading
	local moves = distance or Point.turtleDistance(pta, ptb)
	local weighted = moves

	if (pta.heading % 2) == 0 and pta.z ~= ptb.z then
		moves = moves + 1
		weighted = weighted + .9
		if ptb.heading and (ptb.heading % 2 == 1) then
			heading = ptb.heading
		elseif ptb.z > pta.z then
			heading = 1
		else
			heading = 3
		end
	elseif (pta.heading % 2) == 1 and pta.x ~= ptb.x then
		moves = moves + 1
		weighted = weighted + .9
		if ptb.heading and (ptb.heading % 2 == 0) then
			heading = ptb.heading
		elseif ptb.x > pta.x then
			heading = 0
		else
			heading = 2
		end
	end

	if not ptb.heading then
		return moves, heading, weighted
	end

	-- need to know if we are in digging mode
	-- if so, we need to face blocks -- need a no-backwards flag

	-- calc turns as slightly less than moves
	-- local weighted = moves
	if heading ~= ptb.heading then
		local turns = Point.calculateTurns(heading, ptb.heading)
		moves = moves + turns
		local wturns = { [0] = 0, [1] = .9, [2] = 1.8 }
		weighted = weighted + wturns[turns]
		heading = ptb.heading
	end

	return moves, heading, weighted
end

-- given a set of points, find the one taking the least moves
function Point.closest(reference, pts)
	if #pts == 1 then
		return pts[1]
	end

	local lm, lpt = math.huge
	for _,pt in pairs(pts) do
		local distance = Point.turtleDistance(reference, pt)
		if not reference.heading then
			if distance < lm then
				lpt = pt
				lm = distance
			end
		elseif distance < lm then
			local _, _, m = Point.calculateMoves(reference, pt, distance)
			if m < lm then
				lpt = pt
				lm = m
			end
		end
	end
	return lpt
end

function Point.eachClosest(spt, ipts, fn)
	if not ipts then error('Point.eachClosest: invalid points', 2) end

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

function Point.iterateClosest(spt, ipts)
	local pts = Util.shallowCopy(ipts)
	return function()
		local pt = Point.closest(spt, pts)
		if pt then
			Util.removeByValue(pts, pt)
			return pt
		end
	end
end

function Point.adjacentPoints(pt)
	local pts = { }

	for i = 0, 5 do
		local hi = Point.headings[i]
		table.insert(pts, { x = pt.x + hi.xd, y = pt.y + hi.yd, z = pt.z + hi.zd })
	end

	return pts
end

-- get the point nearest A that is in the direction of B
function Point.nearestTo(pta, ptb)
	local heading

	if pta.x < ptb.x then
		heading = 0
	elseif pta.z < ptb.z then
		heading = 1
	elseif pta.x > ptb.x then
		heading = 2
	elseif pta.z > ptb.z then
		heading = 3
	elseif pta.y < ptb.y then
		heading = 4
	elseif pta.y > ptb.y then
		heading = 5
	end

	if heading then
		return {
			x = pta.x + Point.headings[heading].xd,
			y = pta.y + Point.headings[heading].yd,
			z = pta.z + Point.headings[heading].zd,
		}
	end

	return pta -- error ?
end

function Point.rotate(pt, facing)
	local x, z = pt.x, pt.z
	if facing == 1 then
		pt.x = z
		pt.z = -x
	elseif facing == 2 then
		pt.x = -x
		pt.z = -z
	elseif facing == 3 then
		pt.x = -z
		pt.z = x
	end
end

function Point.makeBox(pt1, pt2)
	return {
		x = pt1.x,
		y = pt1.y,
		z = pt1.z,
		ex = pt2.x,
		ey = pt2.y,
		ez = pt2.z,
	}
end

-- expand box to include point
function Point.expandBox(box, pt)
	if pt.x < box.x then
		box.x = pt.x
	elseif pt.x > box.ex then
		box.ex = pt.x
	end
	if pt.y < box.y then
		box.y = pt.y
	elseif pt.y > box.ey then
		box.ey = pt.y
	end
	if pt.z < box.z then
		box.z = pt.z
	elseif pt.z > box.ez then
		box.ez = pt.z
	end
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
				 pt.y <= box.ey and
				 pt.z <= box.ez
end

function Point.closestPointInBox(pt, box)
	local cpt = {
		x = math.abs(pt.x - box.x) < math.abs(pt.x - box.ex) and box.x or box.ex,
		y = math.abs(pt.y - box.y) < math.abs(pt.y - box.ey) and box.y or box.ey,
		z = math.abs(pt.z - box.z) < math.abs(pt.z - box.ez) and box.z or box.ez,
	}
	cpt.x = pt.x > box.x and pt.x < box.ex and pt.x or cpt.x
	cpt.y = pt.y > box.y and pt.y < box.ey and pt.y or cpt.y
	cpt.z = pt.z > box.z and pt.z < box.ez and pt.z or cpt.z

	return cpt
end

return Point

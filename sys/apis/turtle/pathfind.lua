requireInjector(getfenv(1))

local Grid       = require ("jumper.grid")
local Pathfinder = require ("jumper.pathfinder")
local Point      = require('point')
local Util       = require('util')

local WALKABLE = 0

local function createMap(dim)
	local map = { }
	for z = 1, dim.ez do
		local row = {}
		for x = 1, dim.ex do
			local col = { }
			for y = 1, dim.ey do
				table.insert(col, WALKABLE)
			end
			table.insert(row, col)
		end
		table.insert(map, row)
	end

	return map
end

local function addBlock(map, dim, b)
	map[b.z + dim.oz][b.x + dim.ox][b.y + dim.oy] = 1
end

-- map shrinks/grows depending upon blocks encountered
-- the map will encompass any blocks encountered, the turtle position, and the destination
local function mapDimensions(dest, blocks, boundingBox)
	local sx, sz, sy = turtle.point.x, turtle.point.z, turtle.point.y
	local ex, ez, ey = turtle.point.x, turtle.point.z, turtle.point.y

	local function adjust(pt)
		if pt.x < sx then
			sx = pt.x
		end
		if pt.z < sz then
			sz = pt.z
		end
		if pt.y < sy then
			sy = pt.y
		end
		if pt.x > ex then
			ex = pt.x
		end
		if pt.z > ez then
			ez = pt.z
		end
		if pt.y > ey then
			ey = pt.y
		end
	end

	adjust(dest)

	for _,b in ipairs(blocks) do
		adjust(b)
	end

	-- expand one block out in all directions
	if boundingBox then
		sx = math.max(sx - 1, boundingBox.x)
		sz = math.max(sz - 1, boundingBox.z)
		sy = math.max(sy - 1, boundingBox.y)
		ex = math.min(ex + 1, boundingBox.ex)
		ez = math.min(ez + 1, boundingBox.ez)
		ey = math.min(ey + 1, boundingBox.ey)
	else
		sx = sx - 1
		sz = sz - 1
		sy = sy - 1
		ex = ex + 1
		ez = ez + 1
		ey = ey + 1
	end

	return {
		ex = ex - sx + 1,
		ez = ez - sz + 1, 
		ey = ey - sy + 1, 
		ox = -sx + 1, 
		oz = -sz + 1, 
		oy = -sy + 1
	}
end

local function nodeToString(n)
	return string.format('%d:%d:%d:%d', n._x, n._y, n._z, n.__heading or 9)
end

-- shifting and coordinate flipping
local function pointToMap(dim, pt)
	return { x = pt.x + dim.ox, z = pt.y + dim.oy, y = pt.z + dim.oz }
end

local function nodeToPoint(dim, node)
	return { x = node:getX() - dim.ox, z = node:getY() - dim.oz, y = node:getZ() - dim.oy }
end

local heuristic = function(n, node)

	local m, h = Point.calculateMoves(
			{ x = node._x, z = node._y, y = node._z, heading = node._heading },
			{ x = n._x, z = n._y, y = n._z, heading = n._heading })

	return m, h
end

local function dimsAreEqual(d1, d2)
	return d1.ex == d2.ex and
		   d1.ey == d2.ey and
		   d1.ez == d2.ez and
		   d1.ox == d2.ox and
		   d1.oy == d2.oy and
		   d1.oz == d2.oz
end

-- turtle sensor returns blocks in relation to the world - not turtle orientation
-- so cannot figure out block location unless we know our orientation in the world
-- really kinda dumb since it returns the coordinates as offsets of our location
-- instead of true coordinates
local function addSensorBlocks(blocks, sblocks)

	for _,b in pairs(sblocks) do
		if b.type ~= 'AIR' then
			local pt = { x = turtle.point.x, y = turtle.point.y + b.y, z = turtle.point.z }
			pt.x = pt.x - b.x
			pt.z = pt.z - b.z -- this will only work if we were originally facing west
			local found = false
			for _,ob in pairs(blocks) do
				if pt.x == ob.x and pt.y == ob.y and pt.z == ob.z then
					found = true
					break
				end
			end
			if not found then
				table.insert(blocks, pt)
			end
		end
	end
end

local function pathTo(dest, options)

	local blocks = options.blocks or { }
	local allDests = options.dest or { }  -- support alternative destinations

	local lastDim = nil
	local map = nil
	local grid = nil

	-- Creates a pathfinder object
	local myFinder = Pathfinder(grid, 'ASTAR', walkable)

	myFinder:setMode('ORTHOGONAL')
	myFinder:setHeuristic(heuristic)

	while turtle.point.x ~= dest.x or turtle.point.z ~= dest.z or turtle.point.y ~= dest.y do

		-- map expands as we encounter obstacles
		local dim = mapDimensions(dest, blocks, options.box)

		-- reuse map if possible
		if not lastDim or not dimsAreEqual(dim, lastDim) then
			map = createMap(dim)
			-- Creates a grid object
			grid = Grid(map)
			myFinder:setGrid(grid)
			myFinder:setWalkable(WALKABLE)

			lastDim = dim
		end

		for _,b in ipairs(blocks) do
			addBlock(map, dim, b)
		end

		-- Define start and goal locations coordinates
		local startPt = pointToMap(dim, turtle.point)
		local endPt = pointToMap(dim, dest)

		-- Calculates the path, and its length
		local path = myFinder:getPath(startPt.x, startPt.y, startPt.z, turtle.point.heading, endPt.x, endPt.y, endPt.z, dest.heading)

		if not path then
	    Util.removeByValue(allDests, dest)
	    dest = Point.closest(turtle.point, allDests)

	    if not dest then
				return false, 'failed to recalculate'
			end
		else

			for node, count in path:nodes() do
				local pt = nodeToPoint(dim, node)

				if turtle.abort then
					return false, 'aborted'
				end

				-- use single turn method so the turtle doesn't turn around
				-- when encountering obstacles -- IS THIS RIGHT ??
				if not turtle.gotoSingleTurn(pt.x, pt.z, pt.y, node.heading) then
			  	table.insert(blocks, pt)
			  	if #allDests > 0 then
			  		dest = Point.closest(turtle.point, allDests)
			  	end
			  	--if device.turtlesensorenvironment then
			  	--	addSensorBlocks(blocks, device.turtlesensorenvironment.sonicScan())
			  	--end
					break
				end
			end
		end
	end

	if dest.heading then
		turtle.setHeading(dest.heading)
	end
	return dest
end

return function(dest, options)
	options = options or { }
	if not options.blocks and turtle.gotoPoint(dest) then
		return dest
	end
	return pathTo(dest, options)
end

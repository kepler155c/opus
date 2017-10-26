_G.requireInjector()

local Grid       = require ("jumper.grid")
local Pathfinder = require ("jumper.pathfinder")
local Point      = require('point')
local Util       = require('util')

local turtle = _G.turtle

local function addBlock(grid, b, dim)
	if Point.inBox(b, dim) then
		local node = grid:getNodeAt(b.x, b.y, b.z)
		if node then
			node.walkable = 1
		end
	end
end

-- map shrinks/grows depending upon blocks encountered
-- the map will encompass any blocks encountered, the turtle position, and the destination
local function mapDimensions(dest, blocks, boundingBox, dests)
	local sx, sz, sy = turtle.point.x, turtle.point.z, turtle.point.y
	local ex, ez, ey = turtle.point.x, turtle.point.z, turtle.point.y

	local function adjust(pt)
		if pt.x < sx then
			sx = pt.x
		elseif pt.x > ex then
			ex = pt.x
		end
		if pt.y < sy then
			sy = pt.y
		elseif pt.y > ey then
			ey = pt.y
		end
		if pt.z < sz then
			sz = pt.z
		elseif pt.z > ez then
			ez = pt.z
		end
	end

	adjust(dest)

	for _,d in pairs(dests) do
		adjust(d)
	end

	for _,b in pairs(blocks) do
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
		ex = ex,
		ez = ez,
		ey = ey,
		x = sx,
		z = sz,
		y = sy
	}
end

local function nodeToPoint(node)
	return { x = node:getX(), z = node:getZ(), y = node:getY() }
end

local heuristic = function(n, node)
	local m, h = Point.calculateMoves(
			{ x = node._x, y = node._y, z = node._z, heading = node._heading },
			{ x = n._x, y = n._y, z = n._z, heading = n._heading })

	return m, h
end

local function dimsAreEqual(d1, d2)
	return d1.ex == d2.ex and
		   d1.ey == d2.ey and
		   d1.ez == d2.ez and
		   d1.x == d2.x and
		   d1.y == d2.y and
		   d1.z == d2.z
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

local function selectDestination(pts, box, grid)
	if #pts == 1 then
		return pts[1]
	end
	while #pts > 0 do
		local pt = Point.closest(turtle.point, pts)
		if box and not Point.inBox(pt, box) then
		  Util.removeByValue(pts, pt)
		else
			if grid:isWalkableAt(pt.x, pt.y, pt.z) then
				return pt
			end
	    Util.removeByValue(pts, pt)
	  end
	end
end

local function pathTo(dest, options)
	local blocks = options.blocks or turtle.getState().blocks or { }
	local dests  = options.dest   or { dest }  -- support alternative destinations
	local box    = options.box    or turtle.getState().box

	local lastDim = nil
	local grid = nil

	if box then
		box = Point.normalizeBox(box)
	end

	-- Creates a pathfinder object
	local myFinder = Pathfinder(heuristic)

	while turtle.point.x ~= dest.x or turtle.point.z ~= dest.z or turtle.point.y ~= dest.y do

		-- map expands as we encounter obstacles
		local dim = mapDimensions(dest, blocks, box, dests)

		-- reuse map if possible
		if not lastDim or not dimsAreEqual(dim, lastDim) then
			-- Creates a grid object
			grid = Grid(dim)
			myFinder:setGrid(grid)

			lastDim = dim
		end
		for _,b in pairs(blocks) do
			addBlock(grid, b, dim)
		end

		dest = selectDestination(dests, box, grid)
		if not dest then
--			error('failed to reach destination')
			return false, 'failed to reach destination'
		end
		if turtle.point.x == dest.x and turtle.point.z == dest.z and turtle.point.y == dest.y then
			break
		end

		-- Define start and goal locations coordinates
		local startPt = turtle.point
		local endPt = dest

		-- Calculates the path, and its length
		local path = myFinder:getPath(
			startPt.x, startPt.y, startPt.z, turtle.point.heading,
			endPt.x, endPt.y, endPt.z, dest.heading)

		if not path then
	    Util.removeByValue(dests, dest)
		else
			for node in path:nodes() do
				local pt = nodeToPoint(node)

				if turtle.abort then
					return false, 'aborted'
				end

				-- use single turn method so the turtle doesn't turn around
				-- when encountering obstacles -- IS THIS RIGHT ??
				if not turtle.gotoSingleTurn(pt.x, pt.z, pt.y) then
					table.insert(blocks, pt)
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

return {
	pathfind = function(dest, options)
		options = options or { }
		--if not options.blocks and turtle.gotoPoint(dest) then
		--	return dest
		--end
		return pathTo(dest, options)
	end,

	-- set a global bounding box
	-- box can be overridden by passing box in pathfind options
	setBox = function(box)
		turtle.getState().box = box
	end,

	setBlocks = function(blocks)
		turtle.getState().blocks = blocks
	end,

	addBlock = function(block)
		if turtle.getState().blocks then
			table.insert(turtle.getState().blocks, block)
		end
	end,

	reset = function()
		turtle.getState().box    = nil
		turtle.getState().blocks = nil
	end,
}

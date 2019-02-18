local Grid       = require('jumper.grid')
local Pathfinder = require('jumper.pathfinder')
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
	local box = Point.makeBox(turtle.point, turtle.point)

	Point.expandBox(box, dest)

	for _,d in pairs(dests) do
		Point.expandBox(box, d)
	end

	for _,b in pairs(blocks) do
		Point.expandBox(box, b)
	end

	-- expand one block out in all directions
	if boundingBox then
		box.x = math.max(box.x - 1, boundingBox.x)
		box.z = math.max(box.z - 1, boundingBox.z)
		box.y = math.max(box.y - 1, boundingBox.y)
		box.ex = math.min(box.ex + 1, boundingBox.ex)
		box.ez = math.min(box.ez + 1, boundingBox.ez)
		box.ey = math.min(box.ey + 1, boundingBox.ey)
	else
		box.x = box.x - 1
		box.z = box.z - 1
		box.y = box.y - 1
		box.ex = box.ex + 1
		box.ez = box.ez + 1
		box.ey = box.ey + 1
	end

	return box
end

local function nodeToPoint(node)
	return { x = node.x, y = node.y, z = node.z, heading = node.heading }
end

local function heuristic(n, node)
	return Point.calculateMoves(node, n)
--			{ x = node.x, y = node.y, z = node.z, heading = node.heading },
--			{ x = n.x, y = n.y, z = n.z, heading = n.heading })
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
	local lastDim
	local grid

	if box then
		box = Point.normalizeBox(box)
	end

	-- Creates a pathfinder object
	local finder = Pathfinder(heuristic)

	while turtle.point.x ~= dest.x or turtle.point.z ~= dest.z or turtle.point.y ~= dest.y do

		-- map expands as we encounter obstacles
		local dim = mapDimensions(dest, blocks, box, dests)

		-- reuse map if possible
		if not lastDim or not dimsAreEqual(dim, lastDim) then
			-- Creates a grid object
			grid = Grid(dim)
			finder:setGrid(grid)

			lastDim = dim
		end
		for _,b in pairs(blocks) do
			addBlock(grid, b, dim)
		end

		dest = selectDestination(dests, box, grid)
		if not dest then
			return false, 'failed to reach destination'
		end
		if turtle.point.x == dest.x and turtle.point.z == dest.z and turtle.point.y == dest.y then
			break
		end

		-- Define start and goal locations coordinates
		local startPt = turtle.point

		-- Calculates the path, and its length
		local path = finder:getPath(
			startPt.x, startPt.y, startPt.z, turtle.point.heading,
			dest.x, dest.y, dest.z, dest.heading)

		if not path then
			Util.removeByValue(dests, dest)
		else
			path:filter()

			for node in path:nodes() do
				local pt = nodeToPoint(node)

				if turtle.isAborted() then
					return false, 'aborted'
				end

--if this is the next to last node
--and we are traveling up or down, then the
--heading for this node should be the heading of the last node
--or, maybe..
--if last node is up or down (or either?)

				-- use single turn method so the turtle doesn't turn around
				-- when encountering obstacles
				-- if not turtle.gotoSingleTurn(pt.x, pt.y, pt.z, pt.heading) then
				if not turtle.goto(pt) then
					local bpt = Point.nearestTo(turtle.point, pt)

					table.insert(blocks, bpt)
					-- really need to check if the block we ran into was a turtle.
					-- if so, this block should be temporary (1-2 secs)

					--local side = turtle.getSide(turtle.point, pt)
					--if turtle.isTurtleAtSide(side) then
					--	pt.timestamp = os.clock() + ?
					--end
					-- if dim has not changed, then need to update grid with
					-- walkable = nil (after time has elapsed)

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

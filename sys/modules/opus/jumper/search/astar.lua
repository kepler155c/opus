-- Astar algorithm
-- This actual implementation of A-star is based on
-- [Nash A. & al. pseudocode](http://aigamedev.com/open/tutorials/theta-star-any-angle-paths/)

if (...) then

	-- Internalization
	local huge = math.huge

	-- Dependancies
	local _PATH = (...):match('(.+)%.search.astar$')
	local Heap = require (_PATH.. '.core.bheap')

	-- Updates G-cost
	local function computeCost(node, neighbour, heuristic)
		local mCost, heading = heuristic(neighbour, node) -- Heuristics.EUCLIDIAN(neighbour, node)

		if node._g + mCost < neighbour._g then
			neighbour._parent = node
			neighbour._g = node._g + mCost
			neighbour.heading = heading
		end
	end

	-- Updates vertex node-neighbour
	local function updateVertex(openList, node, neighbour, endNode, heuristic)
		local oldG = neighbour._g
		computeCost(node, neighbour, heuristic)
		if neighbour._g < oldG then
			if neighbour._opened then neighbour._opened = false end
			neighbour._h = heuristic(endNode, neighbour)
			neighbour._f = neighbour._g + neighbour._h
			openList:push(neighbour)
			neighbour._opened = true
		end
	end

	-- Calculates a path.
	-- Returns the path from location `<startX, startY>` to location `<endX, endY>`.
	return function (finder, startNode, endNode, toClear)
		local openList = Heap()
		startNode._g = 0
		startNode._h = finder._heuristic(endNode, startNode)
		startNode._f = startNode._g + startNode._h
		openList:push(startNode)
		toClear[startNode] = true
		startNode._opened = true

		while not openList:empty() do
			local node = openList:pop()
			node._closed = true
			if node == endNode then return node end
			local neighbours = finder._grid:getNeighbours(node)
			for i = 1,#neighbours do
				local neighbour = neighbours[i]
				if not neighbour._closed then
					toClear[neighbour] = true
					if not neighbour._opened then
						neighbour._g = huge
						neighbour._parent = nil
					end
					updateVertex(openList, node, neighbour, endNode, finder._heuristic)
				end
			end

			--[[
			printf('x:%d y:%d z:%d  g:%d', node.x, node.y, node.z, node._g)
			for i = 1,#neighbours do
				local n = neighbours[i]
				printf('x:%d y:%d z:%d f:%f g:%f h:%d', n.x, n.y, n.z, n._f, n._g, n.heading or -1)
			end
			--]]

		end
		return nil
	end
end

--- The Grid class.
-- Implementation of the `grid` class.
-- The `grid` is a implicit graph which represents the 2D
-- world map layout on which the `pathfinder` object will run.
-- During a search, the `pathfinder` object needs to save some critical values.
-- These values are cached within each `node`
-- object, and the whole set of nodes are tight inside the `grid` object itself.

if (...) then

	-- Dependencies
	local _PATH = (...):gsub('%.grid$','')

	-- Local references
	local Utils = require (_PATH .. '.core.utils')
	local Node = require (_PATH .. '.core.node')

	-- Local references
	local setmetatable = setmetatable

	-- Offsets for straights moves
	local straightOffsets = {
		{x = 1, y = 0, z = 0} --[[W]], {x = -1, y =  0, z =  0}, --[[E]]
		{x = 0, y = 1, z = 0} --[[S]], {x =  0, y = -1, z =  0}, --[[N]]
		{x = 0, y = 0, z = 1} --[[U]], {x =  0, y = -0, z = -1}, --[[D]]
	}

	local Grid = {}
	Grid.__index = Grid

	function Grid:new(dim)
		local newGrid = { }
		newGrid._min_x, newGrid._max_x = dim.x, dim.ex
		newGrid._min_y, newGrid._max_y = dim.y, dim.ey
		newGrid._min_z, newGrid._max_z = dim.z, dim.ez
		newGrid._nodes = { }
		newGrid._width = (newGrid._max_x-newGrid._min_x)+1
		newGrid._height = (newGrid._max_y-newGrid._min_y)+1
		newGrid._length = (newGrid._max_z-newGrid._min_z)+1
		return setmetatable(newGrid,Grid)
	end

	function Grid:isWalkableAt(x, y, z)
		local node = self:getNodeAt(x,y,z)
		return node and node.walkable ~= 1
	end

	function Grid:getWidth()
		return self._width
	end

	function Grid:getHeight()
		 return self._height
	end

	function Grid:getNodes()
		return self._nodes
	end

	function Grid:getBounds()
		return self._min_x, self._min_y, self._min_z, self._max_x, self._max_y, self._max_z
	end

	--- Returns neighbours. The returned value is an array of __walkable__ nodes neighbouring a given `node`.
	-- @treturn {node,...} an array of nodes neighbouring a given node
	function Grid:getNeighbours(node)
		local neighbours = {}
		for i = 1,#straightOffsets do
			local n = self:getNodeAt(
				node.x + straightOffsets[i].x,
				node.y + straightOffsets[i].y,
				node.z + straightOffsets[i].z
			)
			if n and self:isWalkableAt(n.x, n.y, n.z) then
				neighbours[#neighbours+1] = n
			end
		end

		return neighbours
	end

 function Grid:getNodeAt(x,y,z)
		if not x or not y or not z then return end
		if Utils.outOfRange(x,self._min_x,self._max_x) then return end
		if Utils.outOfRange(y,self._min_y,self._max_y) then return end
		if Utils.outOfRange(z,self._min_z,self._max_z) then return end

		-- inefficient
		if not self._nodes[y] then self._nodes[y] = {} end
		if not self._nodes[y][x] then self._nodes[y][x] = {} end
		if not self._nodes[y][x][z] then self._nodes[y][x][z] = Node:new(x,y,z) end
		return self._nodes[y][x][z]
	end

	return setmetatable(Grid,{
		__call = function(self,...)
			return self:new(...)
		end
	})

end

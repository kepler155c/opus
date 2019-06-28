--- The Node class.
-- The `node` represents a cell (or a tile) on a collision map. Basically, for each single cell (tile)
-- in the collision map passed-in upon initialization, a `node` object will be generated
-- and then cached within the `grid`.
--
-- In the following implementation, nodes can be compared using the `<` operator. The comparison is
-- made with regards of their `f` cost. From a given node being examined, the `pathfinder` will expand the search
-- to the next neighbouring node having the lowest `f` cost. See `core.bheap` for more details.
--
if (...) then

	local Node = {}
	Node.__index = Node

	function Node:new(x,y,z)
		return setmetatable({x = x, y = y, z = z }, Node)
	end

	-- Enables the use of operator '<' to compare nodes.
	-- Will be used to sort a collection of nodes in a binary heap on the basis of their F-cost
	function Node.__lt(A,B) return (A._f < B._f) end

	function Node:getX() return self.x end
	function Node:getY() return self.y end
	function Node:getZ() return self.z end

	--- Clears temporary cached attributes of a `node`.
	-- Deletes the attributes cached within a given node after a pathfinding call.
	-- This function is internally used by the search algorithms, so you should not use it explicitely.
	function Node:reset()
		self._g, self._h, self._f = nil, nil, nil
		self._opened, self._closed, self._parent = nil, nil, nil
		return self
	end

	return setmetatable(Node,
		{__call = function(_,...)
			return Node:new(...)
		end}
	)
end
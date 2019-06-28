--- The Path class.
-- The `path` class is a structure which represents a path (ordered set of nodes) from a start location to a goal.
-- An instance from this class would be a result of a request addressed to `Pathfinder:getPath`.
--
-- This module is internally used by the library on purpose.
-- It should normally not be used explicitely, yet it remains fully accessible.
--

if (...) then

	local t_remove = table.remove

	local Path = {}
	Path.__index = Path

	function Path:new()
		return setmetatable({_nodes = {}}, Path)
	end

	--- Iterates on each single `node` along a `path`. At each step of iteration,
	-- returns the `node` plus a count value. Aliased as @{Path:nodes}
	-- @usage
	-- for node, count in p:iter() do
	--   ...
	-- end
	function Path:nodes()
		local i = 1
		return function()
			if self._nodes[i] then
				i = i+1
				return self._nodes[i-1],i-1
			end
		end
	end

	--- `Path` compression modifier. Given a `path`, eliminates useless nodes to return a lighter `path`
	-- consisting of straight moves. Does the opposite of @{Path:fill}
	-- @class function
	-- @treturn path self (the calling `path` itself, can be chained)
	-- @see Path:fill
	-- @usage p:filter()
	function Path:filter()
		local i = 2
		local xi,yi,zi,dx,dy,dz, olddx, olddy, olddz
		xi,yi,zi = self._nodes[i].x, self._nodes[i].y, self._nodes[i].z
		dx, dy,dz = xi - self._nodes[i-1].x, yi-self._nodes[i-1].y, zi-self._nodes[i-1].z
		while true do
			olddx, olddy, olddz = dx, dy, dz
			if self._nodes[i+1] then
				i = i+1
				xi, yi, zi = self._nodes[i].x, self._nodes[i].y, self._nodes[i].z
				dx, dy, dz = xi - self._nodes[i-1].x, yi - self._nodes[i-1].y, zi - self._nodes[i-1].z
				if olddx == dx and olddy == dy and olddz == dz then
					t_remove(self._nodes, i-1)
					i = i - 1
				end
			else break end
		end
		return self
	end

	return setmetatable(Path,
		{__call = function(_,...)
			return Path:new(...)
		end
	})
end
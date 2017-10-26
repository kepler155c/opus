--- The Path class.
-- The `path` class is a structure which represents a path (ordered set of nodes) from a start location to a goal.
-- An instance from this class would be a result of a request addressed to `Pathfinder:getPath`.
--
-- This module is internally used by the library on purpose.
-- It should normally not be used explicitely, yet it remains fully accessible.
--

if (...) then
	--- The `Path` class.<br/>
	-- This class is callable.
	-- Therefore, <em><code>Path(...)</code></em> acts as a shortcut to <em><code>Path:new(...)</code></em>.
	-- @type Path
  local Path = {}
  Path.__index = Path

  --- Inits a new `path`.
  -- @class function
  -- @treturn path a `path`
	-- @usage local p = Path()
  function Path:new()
    return setmetatable({_nodes = {}}, Path)
  end

  --- Iterates on each single `node` along a `path`. At each step of iteration,
  -- returns the `node` plus a count value. Aliased as @{Path:nodes}
  -- @class function
  -- @treturn node a `node`
  -- @treturn int the count for the number of nodes
	-- @see Path:nodes
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

  return setmetatable(Path,
    {__call = function(_,...)
      return Path:new(...)
    end
  })
end
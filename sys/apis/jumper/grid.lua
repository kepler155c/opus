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

	--- The `Grid` class.<br/>
	-- This class is callable.
	-- Therefore,_ <code>Grid(...)</code> _acts as a shortcut to_ <code>Grid:new(...)</code>.
	-- @type Grid
  local Grid = {}
  Grid.__index = Grid

  --- Inits a new `grid`
  -- @class function
  -- @tparam table Map dimensions
	-- or a `string` with line-break chars (<code>\n</code> or <code>\r</code>) as row delimiters.
  -- @treturn grid a new `grid` instance
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

  --- Checks if `node` at [x,y] is __walkable__.
	-- Will check if `node` at location [x,y] both *exists* on the collision map and *is walkable*
  -- @class function
  -- @tparam int x the x-location of the node
  -- @tparam int y the y-location of the node
  -- @tparam int z the z-location of the node
	--
  function Grid:isWalkableAt(x, y, z)
    local node = self:getNodeAt(x,y,z)
    return node and node.walkable ~= 1
  end

  --- Returns the `grid` width.
  -- @class function
  -- @treturn int the `grid` width
	-- @usage print(myGrid:getWidth())
  function Grid:getWidth()
    return self._width
  end

  --- Returns the `grid` height.
  -- @class function
  -- @treturn int the `grid` height
	-- @usage print(myGrid:getHeight())
  function Grid:getHeight()
     return self._height
  end

  --- Returns the set of nodes.
  -- @class function
  -- @treturn {{node,...},...} an array of nodes
	-- @usage local nodes = myGrid:getNodes()
  function Grid:getNodes()
    return self._nodes
  end

  --- Returns the `grid` bounds. Returned values corresponds to the upper-left
	-- and lower-right coordinates (in tile units) of the actual `grid` instance.
  -- @class function
  -- @treturn int the upper-left corner x-coordinate
  -- @treturn int the upper-left corner y-coordinate
  -- @treturn int the lower-right corner x-coordinate
  -- @treturn int the lower-right corner y-coordinate
	-- @usage local left_x, left_y, right_x, right_y = myGrid:getBounds()
	function Grid:getBounds()
		return self._min_x, self._min_y, self._min_z, self._max_x, self._max_y, self._max_z
	end

  --- Returns neighbours. The returned value is an array of __walkable__ nodes neighbouring a given `node`.
  -- @class function
  -- @tparam node node a given `node`
  -- @tparam[opt] string|int|func walkable the value for walkable locations
  -- in the collision map array (see @{Grid:new}).
	-- Defaults to __false__ when omitted.
  -- @treturn {node,...} an array of nodes neighbouring a given node
	-- @usage
	-- local aNode = myGrid:getNodeAt(5,6)
	-- local neighbours = myGrid:getNeighbours(aNode, 0, true)
  function Grid:getNeighbours(node)
		local neighbours = {}
    for i = 1,#straightOffsets do
      local n = self:getNodeAt(
        node._x + straightOffsets[i].x,
        node._y + straightOffsets[i].y,
        node._z + straightOffsets[i].z
      )
      if n and self:isWalkableAt(n._x, n._y, n._z) then
        neighbours[#neighbours+1] = n
      end
    end

    return neighbours
  end

  --- Returns the `node` at location [x,y,z].
  -- @class function
  -- @name Grid:getNodeAt
  -- @tparam int x the x-coordinate coordinate
  -- @tparam int y the y-coordinate coordinate
  -- @tparam int z the z-coordinate coordinate
  -- @treturn node a `node`
	-- @usage local aNode = myGrid:getNodeAt(2,2)

  -- Gets the node at location <x,y> on a preprocessed grid
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

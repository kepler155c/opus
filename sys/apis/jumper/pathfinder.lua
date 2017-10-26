--[[
  The following License applies to all files within the jumper directory.

  Note that this is only a partial copy of the full jumper code base. Also,
  the code was modified to support 3D maps.
--]]

--[[
This work is under MIT-LICENSE
Copyright (c) 2012-2013 Roland Yonaba.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
--]]

--- The Pathfinder class

--
-- Implementation of the `pathfinder` class.

local _VERSION = ""
local _RELEASEDATE = ""

if (...) then

  -- Dependencies
  local _PATH = (...):gsub('%.pathfinder$','')
	local Utils     = require (_PATH .. '.core.utils')

  -- Internalization
  local pairs = pairs
  local assert = assert
  local setmetatable = setmetatable

	--- Finders (search algorithms implemented). Refers to the search algorithms actually implemented in Jumper.
	-- <li>[A*](http://en.wikipedia.org/wiki/A*_search_algorithm)</li>
	-- @finder Finders
	-- @see Pathfinder:getFinders
  local Finders = {
    ['ASTAR']     = require (_PATH .. '.search.astar'),
  }

  -- Will keep track of all nodes expanded during the search
  -- to easily reset their properties for the next pathfinding call
  local toClear = {}

  -- Performs a traceback from the goal node to the start node
  -- Only happens when the path was found

	--- The `Pathfinder` class.<br/>
	-- This class is callable.
	-- Therefore,_ <code>Pathfinder(...)</code> _acts as a shortcut to_ <code>Pathfinder:new(...)</code>.
	-- @type Pathfinder
  local Pathfinder = {}
  Pathfinder.__index = Pathfinder

  --- Inits a new `pathfinder`
  -- @class function
  -- @tparam grid grid a `grid`
  -- @tparam[opt] string finderName the name of the `Finder` (search algorithm) to be used for search.
	-- Defaults to `ASTAR` when not given (see @{Pathfinder:getFinders}).
  -- @treturn pathfinder a new `pathfinder` instance
	-- @usage
	-- local finder = Pathfinder:new(myGrid, 'ASTAR')
  function Pathfinder:new(heuristic)
    local newPathfinder = {}
    setmetatable(newPathfinder, Pathfinder)
    self._finder = Finders.ASTAR
    self._heuristic = heuristic
    return newPathfinder
  end

  --- Sets the `grid`. Defines the given `grid` as the one on which the `pathfinder` will perform the search.
  -- @class function
  -- @tparam grid grid a `grid`
	-- @treturn pathfinder self (the calling `pathfinder` itself, can be chained)
	-- @usage myFinder:setGrid(myGrid)
  function Pathfinder:setGrid(grid)
    self._grid = grid
    return self
  end

  --- Calculates a `path`. Returns the `path` from location __[startX, startY]__ to location __[endX, endY]__.
  -- Both locations must exist on the collision map. The starting location can be unwalkable.
  -- @class function
  -- @tparam int startX the x-coordinate for the starting location
  -- @tparam int startY the y-coordinate for the starting location
  -- @tparam int endX the x-coordinate for the goal location
  -- @tparam int endY the y-coordinate for the goal location
  -- @treturn path a path (array of nodes) when found, otherwise nil
	-- @usage local path = myFinder:getPath(1,1,5,5)
  function Pathfinder:getPath(startX, startY, startZ, ih, endX, endY, endZ, oh)
		self:reset()
    local startNode = self._grid:getNodeAt(startX, startY, startZ)
    local endNode = self._grid:getNodeAt(endX, endY, endZ)
    if not startNode or not endNode then
      return nil
    end

    startNode._heading = ih
    endNode._heading = oh

    assert(startNode, ('Invalid location [%d, %d, %d]'):format(startX, startY, startZ))
    assert(endNode and self._grid:isWalkableAt(endX, endY, endZ),
      ('Invalid or unreachable location [%d, %d, %d]'):format(endX, endY, endZ))
    local _endNode = self._finder(self, startNode, endNode, toClear)
    if _endNode then
			return Utils.traceBackPath(self, _endNode, startNode)
    end
    return nil
  end

  --- Resets the `pathfinder`. This function is called internally between
  -- successive pathfinding calls, so you should not
	-- use it explicitely, unless under specific circumstances.
  -- @class function
	-- @treturn pathfinder self (the calling `pathfinder` itself, can be chained)
	-- @usage local path, len = myFinder:getPath(1,1,5,5)
	function Pathfinder:reset()
    for node in pairs(toClear) do node:reset() end
    toClear = {}
		return self
	end

  -- Returns Pathfinder class
	Pathfinder._VERSION = _VERSION
	Pathfinder._RELEASEDATE = _RELEASEDATE
  return setmetatable(Pathfinder,{
    __call = function(self,...)
      return self:new(...)
    end
  })
end

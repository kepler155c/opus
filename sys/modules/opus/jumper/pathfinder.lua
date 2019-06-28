--[[
	The following License applies to all files within the jumper directory.

	Note that this is only a partial copy of the full jumper code base. Also,
	the code was modified to support 3D maps.
--]]

--[[
This work is under MIT-LICENSE
Copyright (c) 2012-2013 Roland Yonaba.

-- https://opensource.org/licenses/MIT

--]]

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
	local Finders = {
		['ASTAR']     = require (_PATH .. '.search.astar'),
	}

	-- Will keep track of all nodes expanded during the search
	-- to easily reset their properties for the next pathfinding call
	local toClear = {}

	-- Performs a traceback from the goal node to the start node
	-- Only happens when the path was found

	local Pathfinder = {}
	Pathfinder.__index = Pathfinder

	function Pathfinder:new(heuristic)
		local newPathfinder = {}
		setmetatable(newPathfinder, Pathfinder)
		self._finder = Finders.ASTAR
		self._heuristic = heuristic
		return newPathfinder
	end

	function Pathfinder:setGrid(grid)
		self._grid = grid
		return self
	end

	--- Calculates a `path`. Returns the `path` from start to end location
	-- Both locations must exist on the collision map. The starting location can be unwalkable.
	-- @treturn path a path (array of nodes) when found, otherwise nil
	-- @usage local path = myFinder:getPath(1,1,5,5)
	function Pathfinder:getPath(startX, startY, startZ, ih, endX, endY, endZ, oh)
		self:reset()
		local startNode = self._grid:getNodeAt(startX, startY, startZ)
		local endNode = self._grid:getNodeAt(endX, endY, endZ)
		if not startNode or not endNode then
			return nil
		end

		startNode.heading = ih
		endNode.heading = oh

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

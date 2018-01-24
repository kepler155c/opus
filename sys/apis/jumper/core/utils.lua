-- Various utilities for Jumper top-level modules

if (...) then

	-- Dependencies
	local _PATH = (...):gsub('%.utils$','')
	local Path = require (_PATH .. '.path')

	-- Local references
	local pairs = pairs
	local t_insert = table.insert

	-- Raw array items count
	local function arraySize(t)
		local count = 0
		for _ in pairs(t) do
			count = count+1
		end
		return count
	end

	-- Extract a path from a given start/end position
	local function traceBackPath(finder, node, startNode)
		local path = Path:new()
		path._grid = finder._grid
		while true do
			if node._parent then
				t_insert(path._nodes,1,node)
				node = node._parent
			else
				t_insert(path._nodes,1,startNode)
				return path
			end
		end
	end

	-- Lookup for value in a table
	local indexOf = function(t,v)
		for i = 1,#t do
			if t[i] == v then return i end
		end
		return nil
	end

	-- Is i out of range
	local function outOfRange(i,low,up)
		return (i< low or i > up)
	end

	return {
		arraySize = arraySize,
		indexOf = indexOf,
		outOfRange = outOfRange,
		traceBackPath = traceBackPath
	}

end

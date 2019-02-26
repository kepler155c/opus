-- convience functions for tables with key/value pairs
local Util = require('util')

local Map = { }

-- TODO: refactor
Map.merge = Util.merge
Map.shallowCopy = Util.shallowCopy

function Map.removeMatches(t, values)
	local function matchAll(entry)
		for k, v in pairs(values) do
			if entry[k] ~= v then
				return
			end
		end
		return true
	end

	for k,v in pairs(t) do
		if matchAll(v) then
			t[k] = nil
		end
	end
end

-- remove table entries if passed function returns false
function Map.prune(t, fn)
	for _,k in pairs(Util.keys(t)) do
		local v = t[k]
		if type(v) == 'table' then
			t[k] = Map.prune(v, fn)
		end
		if not fn(t[k]) then
			t[k] = nil
		end
	end
	return t
end

function Map.size(list)
	local length = 0
	for _ in pairs(list) do
		length = length + 1
	end
	return length
end

return Map

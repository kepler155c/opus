local Util = require('opus.util')

local Array = { }

function Array.filter(it, f)
	local ot = { }
	for _,v in pairs(it) do
		if f(v) then
			table.insert(ot, v)
		end
	end
	return ot
end

function Array.removeByValue(t, e)
	for k,v in pairs(t) do
		if v == e then
			table.remove(t, k)
			return e
		end
	end
end

Array.find = Util.find

return Array

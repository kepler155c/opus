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

return Array

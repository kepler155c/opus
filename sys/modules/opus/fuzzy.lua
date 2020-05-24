local find  = string.find
local floor = math.floor
local min   = math.min
local max   = math.max
local sub   = string.sub

-- https://rosettacode.org/wiki/Jaro_distance (ported to lua)
return function(s1, s2)
	local l1, l2 = #s1, #s2;
	if l1 == 0 then
		return l2 == 0 and 1.0 or 0.0
	end

	local match_distance = max(floor(max(l1, l2) / 2) - 1, 0)
	local s1_matches = { }
	local s2_matches = { }
	local matches = 0

	for i = 1, l1 do
		local _end = min(i + match_distance + 1, l2)
		for k = max(1, i - match_distance), _end do
			if not s2_matches[k] and sub(s1, i, i) == sub(s2, k, k) then
				s1_matches[i] = true
				s2_matches[k] = true
				matches = matches + 1
				break
			end
		end
	end
	if matches == 0 then
		return 0.0
	end

	local t = 0.0
	local k = 1
	for i = 1, l1 do
		if s1_matches[i] then
			while not s2_matches[k] do
				k = k + 1
			end
			if sub(s1, i, i) ~= sub(s2, k, k) then
				t = t + 0.5
			end
			k = k + 1
		end
	end

	-- provide a major boost for exact matches
	local b = 0.0
	if find(s1, s2, 1, true) then
		b = b + .5
	end

	local m = matches
	return (m / l1 + m / l2 + (m - t) / m) / 3.0 + b
end

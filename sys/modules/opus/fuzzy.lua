-- Based on Squid's fuzzy search
-- https://github.com/SquidDev-CC/artist/blob/vnext/artist/lib/match.lua
--
-- not very fuzzy anymore

local SCORE_WEIGHT               = 1000
local LEADING_LETTER_PENALTY     = -30
local LEADING_LETTER_PENALTY_MAX = -90

local _find = string.find
local _max  = math.max

return function(str, pattern)
	local start = _find(str, pattern, 1, true)
	if start then
		-- All letters before the current one are considered leading, so add them to our penalty
		return SCORE_WEIGHT
			+ _max(LEADING_LETTER_PENALTY * (start - 1), LEADING_LETTER_PENALTY_MAX)
			- (#str - #pattern)
	end
end

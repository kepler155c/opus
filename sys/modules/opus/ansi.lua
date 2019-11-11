local Ansi = setmetatable({ }, {
	__call = function(_, ...)
		local str = '\027['
		for k,v in ipairs({ ...}) do
			if k == 1 then
				str = str .. v
			else
				str = str .. ';' .. v
			end
		end
		return str .. 'm'
	end
})

Ansi.codes = {
	reset       = 0,
	white       = 1,
	orange      = 2,
	magenta     = 3,
	lightBlue   = 4,
	yellow      = 5,
	lime        = 6,
	pink        = 7,
	gray        = 8,
	lightGray   = 9,
	cyan        = 10,
	purple      = 11,
	blue        = 12,
	brown       = 13,
	green       = 14,
	red         = 15,
	black       = 16,
	onwhite     = 21,
	onorange    = 22,
	onmagenta   = 23,
	onlightBlue = 24,
	onyellow    = 25,
	onlime      = 26,
	onpink      = 27,
	ongray      = 28,
	onlightGray = 29,
	oncyan      = 30,
	onpurple    = 31,
	onblue      = 32,
	onbrown     = 33,
	ongreen     = 34,
	onred       = 35,
	onblack     = 36,
}

for k,v in pairs(Ansi.codes) do
	Ansi[k] = Ansi(v)
end

return Ansi

local colors = _G.colors
local _rep   = string.rep
local _sub   = string.sub

local Blit = { }

Blit.colorPalette = { }
Blit.grayscalePalette = { }

for n = 1, 16 do
	Blit.colorPalette[2 ^ (n - 1)]     = _sub("0123456789abcdef", n, n)
	Blit.grayscalePalette[2 ^ (n - 1)] = _sub("088888878877787f", n, n)
end

-- default palette
Blit.palette = Blit.colorPalette

function Blit:init(t, args)
	if args then
		for k,v in pairs(args) do
			self[k] = v
		end
	end

	if type(t) == 'string' then
		-- create a blit from a string
		self.text, self.bg, self.fg = Blit.toblit(t, args or { })

	elseif type(t) == 'number' then
		-- create a fixed width blit
		self.width = t
		self.text = _rep(' ', self.width)
		self.bg = _rep(self.palette[args.bg], self.width)
		self.fg = _rep(self.palette[args.fg], self.width)

	else
		self.text = t.text
		self.bg = t.bg
		self.fg = t.fg
	end
end

function Blit:write(x, text, bg, fg)
	self:insert(x, text,
		bg and _rep(self.palette[bg], #text),
		fg and _rep(self.palette[fg], #text))
end

function Blit:insert(x, text, bg, fg)
	if x <= self.width then
		local width = #text
		local tx, tex

		if x < 1 then
			tx = 2 - x
			width = width + x - 1
			x = 1
		end

		if x + width - 1 > self.width then
			tex = self.width - x + (tx or 1)
			width = tex - (tx or 1) + 1
		end

		if width > 0 then
			local function replace(sstr, rstr)
				if tx or tex then
					rstr = _sub(rstr, tx or 1, tex)
				end
				if x == 1 and width == self.width then
					return rstr
				elseif x == 1 then
					return rstr .. _sub(sstr, x + width)
				elseif x + width > self.width then
					return _sub(sstr, 1, x - 1) .. rstr
				end
				return _sub(sstr, 1, x - 1) .. rstr .. _sub(sstr, x + width)
			end

			self.text = replace(self.text, text)
			if fg then
				self.fg = replace(self.fg, fg)
			end
			if bg then
				self.bg = replace(self.bg, bg)
			end
		end
	end
end

function Blit:sub(s, e)
	return Blit({
		text = self.text:sub(s, e),
		bg = self.bg:sub(s, e),
		fg = self.fg:sub(s, e),
	})
end

function Blit:wrap(max)
	local lines = { }
	local data = self

    repeat
		if #data.text <= max then
			table.insert(lines, data)
			break
		elseif data.text:sub(max+1, max+1) == ' ' then
			table.insert(lines, data:sub(1, max))
			data = data:sub(max + 2)
		else
			local x = data.text:sub(1, max)
			local s = x:match('(.*) ') or x
			table.insert(lines, data:sub(1, #s))
			data = data:sub(#s + 1)
		end
		local t = data.text:match('^%s*(.*)')
		local spaces = #data.text - #t
		if spaces > 0 then
			data = data:sub(spaces + 1)
		end
	until not data.text or #data.text == 0

    return lines
end

-- convert a string of text to blit format doing color conversion
-- and processing ansi color sequences
function Blit.toblit(str, cs)
	local text, fg, bg = '', '', ''

	if not cs.cbg then
		-- reset colors
		cs.rbg = cs.bg or colors.black
		cs.rfg = cs.fg or colors.white
		-- current colors
		cs.cbg = cs.rbg
		cs.cfg = cs.rfg

		cs.palette = cs.palette or Blit.palette
	end

	str = str:gsub('(.-)\027%[([%d;]+)m',
		function(k, seq)
			text = text .. k
			bg = bg .. string.rep(cs.palette[cs.cbg], #k)
			fg = fg .. string.rep(cs.palette[cs.cfg], #k)
			for color in string.gmatch(seq, "%d+") do
				color = tonumber(color)
				if color == 0 then
					-- reset to default
					cs.cfg = cs.rfg
					cs.cbg = cs.rbg
				elseif color > 20 then
					cs.cbg = 2 ^ (color - 21)
				else
					cs.cfg = 2 ^ (color - 1)
				end
			end
			return k
		end)

	local k = str:sub(#text + 1)
	return text .. k,
		bg .. string.rep(cs.palette[cs.cbg], #k),
		fg .. string.rep(cs.palette[cs.cfg], #k)
end

return setmetatable(Blit, {
	__call = function(_, ...)
		local obj = setmetatable({ }, { __index = Blit })
		obj:init(...)
		return obj
	end
})

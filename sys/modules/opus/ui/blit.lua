local class = require('opus.class')

local colors = _G.colors

local Blit = class()

function Blit:init(t, cs)
    if type(t) == 'string' then
        t = Blit.toblit(t, cs or { })
    end
    self.text = t.text
    self.bg = t.bg
    self.fg = t.fg
end

function Blit:sub(s, e)
	return Blit({
		text = self.text:sub(s, e),
		bg = self.bg:sub(s, e),
		fg = self.fg:sub(s, e),
	})
end

function Blit:wrap(max)
	local index = 1
	local lines = { }
	local data = self

    repeat
		if #data.text <= max then
			table.insert(lines, data)
			break
		elseif data.text:sub(max+1, max+1) == ' ' then
			table.insert(lines, data:sub(index, max))
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
		cs.rbg = cs.palette[cs.bg or colors.black]
		cs.rfg = cs.palette[cs.fg or colors.white]
		-- current colors
		cs.cbg = cs.rbg
		cs.cfg = cs.rfg
	end

	str = str:gsub('(.-)\027%[([%d;]+)m',
		function(k, seq)
			text = text .. k
			bg = bg .. string.rep(cs.cbg, #k)
			fg = fg .. string.rep(cs.cfg, #k)
			for color in string.gmatch(seq, "%d+") do
				color = tonumber(color)
				if color == 0 then
					-- reset to default
					cs.cfg = cs.rfg
					cs.cbg = cs.rbg
				elseif color > 20 then
					cs.cbg = string.sub("0123456789abcdef", color - 21, color - 21)
				else
					cs.cfg = string.sub("0123456789abcdef", color, color)
				end
			end
			return k
		end)

	local k = str:sub(#text + 1)
	return {
		text = text .. k,
		bg = bg .. string.rep(cs.cbg, #k),
		fg = fg .. string.rep(cs.cfg, #k),
	}
end

return Blit

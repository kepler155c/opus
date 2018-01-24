local colors = _G.colors
local term   = _G.term
local _gsub  = string.gsub
local _rep = string.rep
local _sub = string.sub

local Terminal = { }

-- add scrolling functions to a window
function Terminal.scrollable(win, maxScroll)
	local lines = { }
	local scrollPos = 0
	local oblit, oreposition = win.blit, win.reposition

	local palette = { }
	for n = 1, 16 do
		palette[2 ^ (n - 1)] = _sub("0123456789abcdef", n, n)
	end

	maxScroll = maxScroll or 100

	-- should only do if window is visible...
	local function redraw()
		local _, h = win.getSize()
		local x, y = win.getCursorPos()
		for i = 1, h do
			local line = lines[i + scrollPos]
			if line and line.dirty then
				win.setCursorPos(1, i)
				oblit(line.text, line.fg, line.bg)
				line.dirty = false
			end
		end
		win.setCursorPos(x, y)
	end

	local function scrollTo(p, forceRedraw)
		local _, h = win.getSize()
		local ms = #lines - h            -- max scroll
		p = math.min(math.max(p, 0), ms) -- normalize

		if p ~= scrollPos or forceRedraw then
			scrollPos = p
			for _, line in pairs(lines) do
				line.dirty = true
			end
		end
	end

	function win.write(text)
		local _, h = win.getSize()

		text = tostring(text) or ''
		scrollTo(#lines - h)
		win.blit(text,
			_rep(palette[win.getTextColor()], #text),
			_rep(palette[win.getBackgroundColor()], #text))
		local x, y = win.getCursorPos()
		win.setCursorPos(x + #text, y)
	end

	function win.clearLine()
		local w, h = win.getSize()
		local _, y = win.getCursorPos()

		scrollTo(#lines - h)
		lines[y + scrollPos] = {
			text = _rep(' ', w),
			fg = _rep(palette[win.getTextColor()], w),
			bg = _rep(palette[win.getBackgroundColor()], w),
			dirty = true,
		}
		redraw()
	end

	function win.blit(text, fg, bg)
		local x, y = win.getCursorPos()
		local w, h = win.getSize()

		if y > 0 and y <= h and x <= w then
			local width = #text

			-- fix ffs
			if x < 1 then
				text = _sub(text, 2 - x)
				if bg then
					bg = _sub(bg, 2 - x)
				end
				if bg then
					fg = _sub(fg, 2 - x)
				end
				width = width + x - 1
				x = 1
			end

			if x + width - 1 > w then
				text = _sub(text, 1, w - x + 1)
				if bg then
					bg = _sub(bg, 1, w - x + 1)
				end
				if bg then
					fg = _sub(fg, 1, w - x + 1)
				end
				width = #text
			end

			if width > 0 then
				local function replace(sstr, pos, rstr)
					if pos == 1 and width == w then
						return rstr
					elseif pos == 1 then
						return rstr .. _sub(sstr, pos+width)
					elseif pos + width > w then
						return _sub(sstr, 1, pos-1) .. rstr
					end
					return _sub(sstr, 1, pos-1) .. rstr .. _sub(sstr, pos+width)
				end

				local line = lines[y + scrollPos]
				line.dirty = true
				line.text = replace(line.text, x, text, width)
				if fg then
					line.fg = replace(line.fg, x, fg, width)
				end
				if bg then
					line.bg = replace(line.bg, x, bg, width)
				end
			end
		end
		redraw()
	end

	function win.clear()
		local w, h = win.getSize()

		local text = _rep(' ', w)
		local fg = _rep(palette[win.getTextColor()], w)
		local bg = _rep(palette[win.getBackgroundColor()], w)
		lines = { }
		for y = 1, h do
			lines[y] = {
				dirty = true,
				text = text,
				fg = fg,
				bg = bg,
			}
		end
		scrollPos = 0
		redraw()
	end

	-- doesn't support negative scrolling...
	function win.scroll(n)
		local w = win.getSize()

		for _ = 1, n do
			lines[#lines + 1] = {
				text = _rep(' ', w),
				fg = _rep(palette[win.getTextColor()], w),
				bg = _rep(palette[win.getBackgroundColor()], w),
			}
		end

		while #lines > maxScroll do
			table.remove(lines, 1)
		end

		scrollTo(maxScroll, true)
		redraw()
	end

	function win.scrollUp()
		scrollTo(scrollPos - 1)
		redraw()
	end

	function win.scrollDown()
		scrollTo(scrollPos + 1)
		redraw()
	end

	function win.reposition(x, y, nw, nh)
		local w, h = win.getSize()
		local D = (nh or h) - h

		if D > 0 then
			for _ = 1, D do
				lines[#lines + 1] = {
					text = _rep(' ', w),
					fg = _rep(palette[win.getTextColor()], w),
					bg = _rep(palette[win.getBackgroundColor()], w),
				}
			end
		elseif D < 0 then
			for _ = D, -1 do
				lines[#lines] = nil
			end
		end
		return oreposition(x, y, nw, nh)
	end

	win.clear()
end

-- get windows contents
function Terminal.getContents(win, parent)
	local oblit, oscp = parent.blit, parent.setCursorPos
	local lines = { }

	parent.blit = function(text, fg, bg)
		lines[#lines + 1] = {
			text = text,
			fg = fg,
			bg = bg,
		}
	end
	parent.setCursorPos = function() end

	win.setVisible(true)
	win.redraw()

	parent.blit = oblit
	parent.setCursorPos = oscp

	return lines
end

function Terminal.toGrayscale(ct)
	local scolors = {
		[ colors.white ] = colors.white,
		[ colors.orange ] = colors.lightGray,
		[ colors.magenta ] = colors.lightGray,
		[ colors.lightBlue ] = colors.lightGray,
		[ colors.yellow ] = colors.lightGray,
		[ colors.lime ] = colors.lightGray,
		[ colors.pink ] = colors.lightGray,
		[ colors.gray ] = colors.gray,
		[ colors.lightGray ] = colors.lightGray,
		[ colors.cyan ] = colors.lightGray,
		[ colors.purple ] = colors.gray,
		[ colors.blue ] = colors.gray,
		[ colors.brown ] = colors.gray,
		[ colors.green ] = colors.lightGray,
		[ colors.red ] = colors.gray,
		[ colors.black ] = colors.black,
	}

	local methods = { 'setBackgroundColor', 'setBackgroundColour',
										'setTextColor', 'setTextColour' }
	for _,v in pairs(methods) do
		local fn = ct[v]
		ct[v] = function(c)
			fn(scolors[c])
		end
	end

	local bcolors = {
		[ '1' ] = '8',
		[ '2' ] = '8',
		[ '3' ] = '8',
		[ '4' ] = '8',
		[ '5' ] = '8',
		[ '6' ] = '8',
		[ '9' ] = '8',
		[ 'a' ] = '7',
		[ 'b' ] = '7',
		[ 'c' ] = '7',
		[ 'd' ] = '8',
		[ 'e' ] = '7',
	}

	local function translate(s)
		if s then
			s = _gsub(s, "%w", bcolors)
		end
		return s
	end

	local fn = ct.blit
	ct.blit = function(text, fg, bg)
		fn(text, translate(fg), translate(bg))
	end
end

function Terminal.getNullTerm(ct)
	local nt = Terminal.copy(ct)

	local methods = { 'blit', 'clear', 'clearLine', 'scroll',
										'setCursorBlink', 'setCursorPos', 'write' }
	for _,v in pairs(methods) do
		nt[v] = function() end
	end

	return nt
end

function Terminal.copy(it, ot)
	ot = ot or { }
	for k,v in pairs(it) do
		if type(v) == 'function' then
			ot[k] = v
		end
	end
	return ot
end

function Terminal.mirror(ct, dt)
	for k,f in pairs(ct) do
		ct[k] = function(...)
			local ret = { f(...) }
			if dt[k] then
				dt[k](...)
			end
			return table.unpack(ret)
		end
	end
end

function Terminal.readPassword(prompt)
	if prompt then
		term.write(prompt)
	end
	local fn = term.current().write
	term.current().write = function() end
	local s
	pcall(function() s = _G.read(prompt) end)
	term.current().write = fn

	if s == '' then
		return
	end
	return s
end

return Terminal

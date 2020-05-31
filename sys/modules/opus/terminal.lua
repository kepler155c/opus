local Canvas = require('opus.ui.canvas')

local colors = _G.colors
local term   = _G.term
local _gsub  = string.gsub

local Terminal = { }

local mapColorToGray = {
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

-- Replacement for window api with scrolling and buffering
function Terminal.window(parent, sx, sy, w, h, isVisible)
	isVisible = isVisible ~= false
	if not w or not h then
		w, h = parent.getSize()
	end

	local win = { }
	local maxScroll
	local cx, cy = 1, 1
	local blink = false
	local _bg, _fg = colors.black, colors.white

	win.canvas = Canvas({
		x       = sx,
		y       = sy,
		width   = w,
		height  = h,
		isColor = parent.isColor(),
		offy    = 0,
		bg      = _bg,
		fg      = _fg,
	})

	local function update()
		if isVisible then
			win.canvas:render(parent)
			win.setCursorPos(cx, cy)
		end
	end

	local function scrollTo(y)
		y = math.max(0, y)
		y = math.min(#win.canvas.lines - win.canvas.height, y)

		if y ~= win.canvas.offy then
			win.canvas.offy = y
			win.canvas:dirty()
			update()
		end
	end

	function win.write(str)
		str = tostring(str) or ''
		win.canvas:write(cx, cy +  win.canvas.offy, str, win.canvas.bg, win.canvas.fg)
		win.setCursorPos(cx + #str, cy)
		update()
	end

	function win.blit(str, fg, bg)
		win.canvas:blit(cx, cy + win.canvas.offy, str, bg, fg)
		win.setCursorPos(cx + #str, cy)
		update()
	end

	function win.clear()
		win.canvas.offy = 0
		for i = #win.canvas.lines, win.canvas.height + 1, -1 do
			win.canvas.lines[i] = nil
		end
		win.canvas:clear()
		update()
	end

	function win.getLine(n)
		local line = win.canvas.lines[n]
		return line.text, line.fg, line.bg
	end

	function win.clearLine()
		win.canvas:clearLine(cy + win.canvas.offy)
		win.setCursorPos(cx, cy)
		update()
	end

	function win.getCursorPos()
		return cx, cy
	end

	function win.setCursorPos(x, y)
		cx, cy = math.floor(x), math.floor(y)
		if isVisible then
			parent.setCursorPos(cx + win.canvas.x - 1, cy + win.canvas.y - 1)
		end
	end

	function win.getCursorBlink()
		return blink
	end

	function win.setCursorBlink(b)
		blink = b
		if isVisible then
			parent.setCursorBlink(b)
		end
	end

	function win.isColor()
		return win.canvas.isColor
	end
	win.isColour = win.isColor

	function win.setTextColor(c)
		win.canvas.fg = c
	end
	win.setTextColour = win.setTextColor

	function win.getPaletteColor(n)
		if parent.getPaletteColor then
			return parent.getPaletteColor(n)
		end
		return 0, 0, 0
	end
	win.getPaletteColour = win.getPaletteColor

	function win.setPaletteColor(n, r, g, b)
		if parent.setPaletteColor then
			return parent.setPaletteColor(n, r, g, b)
		end
	end
	win.setPaletteColour = win.setPaletteColor

	function win.setBackgroundColor(c)
		win.canvas.bg = c
	end
	win.setBackgroundColour = win.setBackgroundColor

	function win.getSize()
		return win.canvas.width, win.canvas.height
	end

	function win.scroll(n)
		n = n or 1
		if n > 0 then
			local lines = #win.canvas.lines
			for i = 1, n do
				win.canvas.lines[lines + i] = { }
				win.canvas:clearLine(lines + i)
			end
			while #win.canvas.lines > (maxScroll or win.canvas.height) do
				table.remove(win.canvas.lines, 1)
			end
			scrollTo(#win.canvas.lines)
			win.canvas:dirty()
			update()
		end
	end

	function win.getTextColor()
		return win.canvas.fg
	end
	win.getTextColour = win.getTextColor

	function win.getBackgroundColor()
		return win.canvas.bg
	end
	win.getBackgroundColour = win.getBackgroundColor

	function win.setVisible(visible)
		if visible ~= isVisible then
			isVisible = visible
			if isVisible then
				win.canvas:dirty()
				update()
			end
		end
	end

	function win.redraw()
		if isVisible then
			win.canvas:dirty()
			update()
		end
	end

	function win.restoreCursor()
		if isVisible then
			win.setCursorPos(cx, cy)
			win.setTextColor(win.canvas.fg)
			win.setCursorBlink(blink)
		end
	end

	function win.getPosition()
		return win.canvas.x, win.canvas.y
	end

	function win.reposition(x, y, width, height)
		if not maxScroll then
			win.canvas:move(x, y)
			win.canvas:resize(width or win.canvas.width, height or win.canvas.height)
			return
		end

		-- special processing for scrolling terminal like windows
		local delta = height - win.canvas.height

		if delta > 0 then -- grow
			for _ = 1, delta do
				win.canvas.lines[#win.canvas.lines + 1] = { }
				win.canvas:clearLine(#win.canvas.lines)
			end

		elseif delta < 0 then -- shrink
			for _ = delta + 1, 0 do
				if cy < win.canvas.height then
					win.canvas.lines[#win.canvas.lines] = nil
				else
					cy = cy - 1
					win.canvas.offy = win.canvas.offy + 1
				end
			end
		end

		win.canvas:resizeBuffer(width, #win.canvas.lines)

		win.canvas.height = height
		win.canvas.width = width
		win.canvas:move(x, y)

		update()
	end

	--[[ Additional methods ]]--
	function win.scrollDown()
		scrollTo(win.canvas.offy + 1)
	end

	function win.scrollUp()
		scrollTo(win.canvas.offy - 1)
	end

	function win.scrollTop()
		scrollTo(0)
	end

	function win.scrollBottom()
		scrollTo(#win.canvas.lines)
	end

	function win.setMaxScroll(ms)
		maxScroll = ms
	end

	function win.getCanvas()
		return win.canvas
	end

	function win.getParent()
		return parent
	end

	function win.writeX(sText)
		-- expect(1, sText, "string", "number")
		local nLinesPrinted = 0
		local function newLine()
			if cy + 1 <= win.canvas.height then
				cx, cy = 1, cy + 1
			else
				cx, cy = 1, win.canvas.height
				win.scroll(1)
			end
			nLinesPrinted = nLinesPrinted + 1
		end

		-- Print the line with proper word wrapping
		sText = tostring(sText)
		while #sText > 0 do
			local whitespace = string.match(sText, "^[ \t]+")
			if whitespace then
				-- Print whitespace
				win.write(whitespace)
				sText = string.sub(sText, #whitespace + 1)
			end

			local newline = string.match(sText, "^\n")
			if newline then
				-- Print newlines
				newLine()
				sText = string.sub(sText, 2)
			end

			local text = string.match(sText, "^[^ \t\n]+")
			if text then
				sText = string.sub(sText, #text + 1)
				if #text > win.canvas.width then
					-- Print a multiline word
					while #text > 0 do
						if cx > win.canvas.width then
							newLine()
						end
						win.write(text)
						text = string.sub(text, win.canvas.width - cx + 2)
					end
				else
					-- Print a word normally
					if cx + #text - 1 > win.canvas.width then
						newLine()
					end
					win.write(text)
				end
			end
		end

		return nLinesPrinted
	end

	function win.print(...)
		local vis = isVisible
		isVisible = false
		local nLinesPrinted = 0
		local nLimit = select("#", ...)
		for n = 1, nLimit do
			local s = tostring(select(n, ...))
			if n < nLimit then
				s = s .. "\t"
			end
			nLinesPrinted = nLinesPrinted + win.writeX(s)
		end
		nLinesPrinted = nLinesPrinted + win.writeX("\n")
		isVisible = vis
		update()
		return nLinesPrinted
	end

	win.canvas:clear()

	return win
end

-- get windows contents
function Terminal.getContents(win)
	if not win.getLine then
		error('window is required')
	end

	local lines = { }
	local _, h = win.getSize()

	for i = 1, h do
		local text, fg, bg = win.getLine(i)
		lines[i] = {
			text = text,
			fg = fg,
			bg = bg,
		}
	end

	return lines
end

function Terminal.colorToGrayscale(c)
	return mapColorToGray[c]
end

function Terminal.toGrayscale(ct)
	local methods = { 'setBackgroundColor', 'setBackgroundColour',
										'setTextColor', 'setTextColour' }
	for _,v in pairs(methods) do
		local fn = ct[v]
		ct[v] = function(c)
			fn(mapColorToGray[c])
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
	local t = { }
	for k,f in pairs(ct) do
		t[k] = function(...)
			local ret = { f(...) }
			if dt[k] then
				dt[k](...)
			end
			return table.unpack(ret)
		end
	end
	return t
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

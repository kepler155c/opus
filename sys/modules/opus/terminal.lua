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
	local maxScroll = 100
	local cx, cy = 1, 1
	local blink = false
	local bg, fg = parent.getBackgroundColor(), parent.getTextColor()

	local canvas = Canvas({
		x       = sx,
		y       = sy,
		width   = w,
		height  = h,
		isColor = parent.isColor(),
		offy    = 0,
	})

	win.canvas = canvas

	local function update()
		if isVisible then
			canvas:render(parent)
			win.setCursorPos(cx, cy)
		end
	end

	local function scrollTo(y)
		y = math.max(0, y)
		y = math.min(#canvas.lines - canvas.height, y)

		if y ~= canvas.offy then
			canvas.offy = y
			canvas:dirty()
			update()
		end
	end

	function win.write(str)
		str = tostring(str) or ''
		canvas:write(cx, cy + canvas.offy, str, bg, fg)
		win.setCursorPos(cx + #str, cy)
		update()
	end

	function win.blit(str, fg, bg)
		canvas:blit(cx, cy + canvas.offy, str, bg, fg)
		win.setCursorPos(cx + #str, cy)
		update()
	end

	function win.clear()
		canvas.offy = 0
		for i = #canvas.lines, canvas.height + 1, -1 do
			canvas.lines[i] = nil
		end
		canvas:clear(bg, fg)
		update()
	end

	function win.clearLine()
		canvas:clearLine(cy + canvas.offy, bg, fg)
		win.setCursorPos(cx, cy)
		update()
	end

	function win.getCursorPos()
		return cx, cy
	end

	function win.setCursorPos(x, y)
		cx, cy = math.floor(x), math.floor(y)
		if isVisible then
			parent.setCursorPos(cx + canvas.x - 1, cy + canvas.y - 1)
		end
	end

	function win.setCursorBlink(b)
		blink = b
		if isVisible then
			parent.setCursorBlink(b)
		end
	end

	function win.isColor()
		return canvas.isColor
	end
	win.isColour = win.isColor

	function win.setTextColor(c)
		fg = c
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
		bg = c
	end
	win.setBackgroundColour = win.setBackgroundColor

	function win.getSize()
		return canvas.width, canvas.height
	end

	function win.scroll(n)
		n = n or 1
		if n > 0 then
			local lines = #canvas.lines
			for i = 1, n do
				canvas.lines[lines + i] = { }
				canvas:clearLine(lines + i, bg, fg)
			end
			while #canvas.lines > maxScroll do
				table.remove(canvas.lines, 1)
			end
			scrollTo(#canvas.lines)
			canvas:dirty()
			update()
		end
	end

	function win.getTextColor()
		return fg
	end
	win.getTextColour = win.getTextColor

	function win.getBackgroundColor()
		return bg
	end
	win.getBackgroundColour = win.getBackgroundColor

	function win.setVisible(visible)
		if visible ~= isVisible then
			isVisible = visible
			if isVisible then
				canvas:dirty()
				update()
			end
		end
	end

	function win.redraw()
		if isVisible then
			canvas:dirty()
			update()
		end
	end

	function win.restoreCursor()
		if isVisible then
			win.setCursorPos(cx, cy)
			win.setTextColor(fg)
			win.setCursorBlink(blink)
		end
	end

	function win.getPosition()
		return canvas.x, canvas.y
	end

	function win.reposition(x, y, width, height)
		canvas.x, canvas.y = x, y
		canvas:resize(width or canvas.width, height or canvas.height)
	end

	--[[ Additional methods ]]--
	function win.scrollDown()
		scrollTo(canvas.offy + 1)
	end

	function win.scrollUp()
		scrollTo(canvas.offy - 1)
	end

	function win.scrollTop()
		scrollTo(0)
	end

	function win.scrollBottom()
		scrollTo(#canvas.lines)
	end

	function win.setMaxScroll(ms)
		maxScroll = ms
	end

	function win.getCanvas()
		return canvas
	end

	function win.getParent()
		return parent
	end

	canvas:clear()

	return win
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

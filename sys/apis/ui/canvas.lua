local class  = require('class')
local Region = require('ui.region')
local Util   = require('util')

local _rep   = string.rep
local _sub   = string.sub
local _gsub  = string.gsub
local colors = _G.colors

local Canvas = class()

Canvas.colorPalette = { }
Canvas.darkPalette = { }
Canvas.grayscalePalette = { }

for n = 1, 16 do
	Canvas.colorPalette[2 ^ (n - 1)]     = _sub("0123456789abcdef", n, n)
	Canvas.grayscalePalette[2 ^ (n - 1)] = _sub("088888878877787f", n, n)
	Canvas.darkPalette[2 ^ (n - 1)]      = _sub("8777777f77fff77f", n, n)
end

--[[
	A canvas can have more lines than canvas.height in order to scroll
]]

function Canvas:init(args)
	self.x = 1
	self.y = 1
	self.layers = { }

	Util.merge(self, args)

	self.ex = self.x + self.width - 1
	self.ey = self.y + self.height - 1

	if not self.palette then
		if self.isColor then
			self.palette = Canvas.colorPalette
		else
			self.palette = Canvas.grayscalePalette
		end
	end

	self.lines = { }
	for i = 1, self.height do
		self.lines[i] = { }
	end
end

function Canvas:move(x, y)
	self.x, self.y = x, y
	self.ex = self.x + self.width - 1
	self.ey = self.y + self.height - 1
end

function Canvas:resize(w, h)
	for i = #self.lines, h do
		self.lines[i] = { }
	end

	while #self.lines > h do
		table.remove(self.lines, #self.lines)
	end

	if w ~= self.width then
		for i = 1, self.height do
			self.lines[i] = { dirty = true }
		end
	end

	self.ex = self.x + w - 1
	self.ey = self.y + h - 1
	self.width = w
	self.height = h
end

function Canvas:copy()
	local b = Canvas({
		x       = self.x,
		y       = self.y,
		width   = self.width,
		height  = self.height,
		isColor = self.isColor,
	})
	for i = 1, #self.lines do
		b.lines[i].text = self.lines[i].text
		b.lines[i].fg = self.lines[i].fg
		b.lines[i].bg = self.lines[i].bg
	end
	return b
end

function Canvas:addLayer(layer)
	local canvas = Canvas({
		x       = layer.x,
		y       = layer.y,
		width   = layer.width,
		height  = layer.height,
		isColor = self.isColor,
	})
	canvas.parent = self
	table.insert(self.layers, canvas)
	return canvas
end

function Canvas:removeLayer()
	for k, layer in pairs(self.parent.layers) do
		if layer == self then
			self:setVisible(false)
			table.remove(self.parent.layers, k)
			break
		end
	end
end

function Canvas:setVisible(visible)
	self.visible = visible
	if not visible and self.parent then
		self.parent:dirty()
		-- TODO: set parent's lines to dirty for each line in self
	end
end

-- Push a layer to the top
function Canvas:raise()
	if self.parent then
		local layers = self.parent.layers or { }
		for k, v in pairs(layers) do
			if v == self then
				table.insert(layers, table.remove(layers, k))
				break
			end
		end
	end
end

function Canvas:write(x, y, text, bg, fg)
	if bg then
		bg = _rep(self.palette[bg], #text)
	end
	if fg then
		fg = _rep(self.palette[fg], #text)
	end
	self:blit(x, y, text, bg, fg)
end

function Canvas:blit(x, y, text, bg, fg)
	if y > 0 and y <= #self.lines and x <= self.width then
		local width = #text

		-- fix ffs
		if x < 1 then
			text = _sub(text, 2 - x)
			if bg then
				bg = _sub(bg, 2 - x)
			end
			if fg then
				fg = _sub(fg, 2 - x)
			end
			width = width + x - 1
			x = 1
		end

		if x + width - 1 > self.width then
			text = _sub(text, 1, self.width - x + 1)
			if bg then
				bg = _sub(bg, 1, self.width - x + 1)
			end
			if fg then
				fg = _sub(fg, 1, self.width - x + 1)
			end
			width = #text
		end

		if width > 0 then

			local function replace(sstr, pos, rstr)
				if pos == 1 and width == self.width then
					return rstr
				elseif pos == 1 then
					return rstr .. _sub(sstr, pos+width)
				elseif pos + width > self.width then
					return _sub(sstr, 1, pos-1) .. rstr
				end
				return _sub(sstr, 1, pos-1) .. rstr .. _sub(sstr, pos+width)
			end

			local line = self.lines[y]
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
end

function Canvas:writeLine(y, text, fg, bg)
	self.lines[y].dirty = true
	self.lines[y].text = text
	self.lines[y].fg = fg
	self.lines[y].bg = bg
end

function Canvas:clearLine(y, bg, fg)
	fg = _rep(self.palette[fg or colors.white], self.width)
	bg = _rep(self.palette[bg or colors.black], self.width)
	self:writeLine(y, _rep(' ', self.width), fg, bg)
end

function Canvas:clear(bg, fg)
	local text = _rep(' ', self.width)
	fg = _rep(self.palette[fg or colors.white], self.width)
	bg = _rep(self.palette[bg or colors.black], self.width)
	for i = 1, #self.lines do
		self:writeLine(i, text, fg, bg)
	end
end

function Canvas:punch(rect)
	local offset = { x = 0, y = 0 }


	self.regions:subRect(rect.x + offset.x, rect.y + offset.y, rect.ex + offset.x, rect.ey + offset.y)
end

function Canvas:blitClipped(device, offset)
	offset = { x = self.x, y = self.y }
	local parent = self.parent
	while parent do
		offset.x = offset.x + parent.x - 1
		offset.y = offset.y + parent.y - 1
		parent = parent.parent
	end
	for _,region in ipairs(self.regions.region) do
		self:blitRect(device,
			{ x = region[1],
				y = region[2],
				ex = region[3],
				ey = region[4] },
			{ x = region[1] + offset.x - 1, y = region[2] + offset.y - 1 })
	end
end

function Canvas:redraw(device)
--[[
	if #self.layers > 0 then
		for _,layer in pairs(self.layers) do
			self:punch(layer)
		end
		self:blitClipped(device)
	else
		self:blit(device)
	end
	self:clean()
]]
end

function Canvas:isDirty()
	for i = 1, #self.lines do
		if self.lines[i].dirty then
			return true
		end
	end
end

function Canvas:dirty()
	for i = 1, #self.lines do
		self.lines[i].dirty = true
	end
	if self.layers then
		for _, canvas in pairs(self.layers) do
			canvas:dirty()
		end
	end
end

function Canvas:clean()
	for i = 1, #self.lines do
		self.lines[i].dirty = nil
	end
end

function Canvas:renderLayers(device, offset)
	if not offset then
		offset = { x = self.x, y = self.y }
	end
	if #self.layers > 0 then
		self.regions = Region.new(1, 1, self.ex, self.ey)

		for i = 1, #self.layers do
			local canvas = self.layers[i]
			if canvas.visible then

				-- punch out this area from the parent's canvas
				self:punch(canvas)

				-- get the area to render for this layer
				canvas.regions = Region.new(canvas.x, canvas.y, canvas.ex, canvas.ey)

				-- determine if we should render this layer by punching
				-- out any layers that overlap this one
				for j  = i + 1, #self.layers do
					if self.layers[j].visible then
						canvas:punch(self.layers[j])
					end
				end
			end
		end

		for _, canvas in ipairs(self.layers) do
			if canvas.visible and #canvas.regions.region > 0 then
				canvas:renderLayers(device, {
					x = canvas.x, --offset.x + self.x - 1,
					y = canvas.y,
				})
			end
		end

		self:blitClipped(device, offset)

	--elseif #self.regions.region > 0 then
	--	self:blitClipped(device, offset)

	else
		offset = { x = self.x, y = self.y }
		local parent = self.parent
		while parent do
			offset.x = offset.x + parent.x - 1
			offset.y = offset.y + parent.y - 1
			parent = parent.parent
		end
		self:blitRect(device, nil, offset)
	end
	self:clean()
end

function Canvas:render(device)
	--_G._p = self
	if #self.layers > 0 then
		self:renderLayers(device)
	else
		self:blitRect(device)
		self:clean()
	end
end

function Canvas:blitRect(device, src, tgt)
	src = src or { x = 1, y = 1, ex = self.ex - self.x + 1, ey = self.ey - self.y + 1 }
	tgt = tgt or self

	for i = 0, src.ey - src.y do
		local line = self.lines[src.y + i + (self.offy or 0)]
		if line and line.dirty then
			local t, fg, bg = line.text, line.fg, line.bg
			if src.x > 1 or src.ex < self.ex then
				t  = _sub(t, src.x, src.ex)
				fg = _sub(fg, src.x, src.ex)
				bg = _sub(bg, src.x, src.ex)
			end
			device.setCursorPos(tgt.x, tgt.y + i)
			device.blit(t, fg, bg)
		end
	end
	--os.sleep(.1)
end

function Canvas:applyPalette(palette)

	local lookup = { }
	for n = 1, 16 do
		lookup[self.palette[2 ^ (n - 1)]] = palette[2 ^ (n - 1)]
	end

	for _, l in pairs(self.lines) do
		l.fg = _gsub(l.fg, '%w', lookup)
		l.bg = _gsub(l.bg, '%w', lookup)
		l.dirty = true
	end

	self.palette = palette
end

function Canvas.convertWindow(win, parent, wx, wy)
	local w, h = win.getSize()

	win.canvas = Canvas({
		x       = wx,
		y       = wy,
		width   = w,
		height  = h,
		isColor = win.isColor(),
	})

	function win.clear()
		win.canvas:clear(win.getBackgroundColor(), win.getTextColor())
	end

	function win.clearLine()
		local _, y = win.getCursorPos()
		win.canvas:write(1,
			y,
			_rep(' ', win.canvas.width),
			win.getBackgroundColor(),
			win.getTextColor())
	end

	function win.write(str)
		local x, y = win.getCursorPos()
		win.canvas:write(x,
			y,
			str,
			win.getBackgroundColor(),
			win.getTextColor())
		win.setCursorPos(x + #str, y)
	end

	function win.blit(text, fg, bg)
		local x, y = win.getCursorPos()
		win.canvas:blit(x, y, text, bg, fg)
	end

	function win.redraw()
		win.canvas:redraw(parent)
	end

	function win.scroll(n)
		table.insert(win.canvas.lines, table.remove(win.canvas.lines, 1))
		win.canvas.lines[#win.canvas.lines].text = _rep(' ', win.canvas.width)
		win.canvas:dirty()
	end

	function win.reposition(x, y, width, height)
		win.canvas.x, win.canvas.y = x, y
		win.canvas:resize(width or win.canvas.width, height or win.canvas.height)
	end

	win.clear()
end

return Canvas

local class  = require('opus.class')
local Region = require('opus.ui.region')
local Util   = require('opus.util')

local _rep   = string.rep
local _sub   = string.sub
local _gsub  = string.gsub
local colors = _G.colors

local Canvas = class()

local function genPalette(map)
	local t = { }
	local rcolors = Util.transpose(colors)
	for n = 1, 16 do
		local pow = 2 ^ (n - 1)
		local ch = _sub(map, n, n)
		t[pow] = ch
		t[rcolors[pow]] = ch
	end
	return t
end

Canvas.colorPalette     = genPalette('0123456789abcdef')
Canvas.grayscalePalette = genPalette('088888878877787f')

--[[
	A canvas can have more lines than canvas.height in order to scroll

	TODO: finish vertical scrolling
]]
function Canvas:init(args)
	self.bg = colors.black
	self.fg = colors.white

	Util.merge(self, args)

	self.x = self.x or 1
	self.y = self.y or 1
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

	self:clear()
end

function Canvas:move(x, y)
	self.x, self.y = x, y
	self.ex = self.x + self.width - 1
	self.ey = self.y + self.height - 1
	if self.parent then
		self.parent:dirty(true)
	end
end

function Canvas:resize(w, h)
	self:resizeBuffer(w, h)

	self.ex = self.x + w - 1
	self.ey = self.y + h - 1
	self.width = w
	self.height = h
end

-- resize the canvas buffer - not the canvas itself
function Canvas:resizeBuffer(w, h)
	for i = #self.lines + 1, h do
		self.lines[i] = { }
		self:clearLine(i)
	end

	while #self.lines > h do
		table.remove(self.lines, #self.lines)
	end

	if w < self.width then
		for i = 1, h do
			local ln = self.lines[i]
			ln.text = _sub(ln.text, 1, w)
			ln.fg = _sub(ln.fg, 1, w)
			ln.bg = _sub(ln.bg, 1, w)
		end
	elseif w > self.width then
		local d = w - self.width
		local text = _rep(' ', d)
		local fg = _rep(self.palette[self.fg], d)
		local bg = _rep(self.palette[self.bg], d)
		for i = 1, h do
			local ln = self.lines[i]
			ln.text = ln.text .. text
			ln.fg = ln.fg .. fg
			ln.bg = ln.bg .. bg
			ln.dirty = true
		end
	end
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
	layer.parent = self
	if not self.children then
		self.children = { }
	end
	table.insert(self.children, 1, layer)
	return layer
end

function Canvas:removeLayer()
	for k, layer in pairs(self.parent.children) do
		if layer == self then
			self:setVisible(false)
			table.remove(self.parent.children, k)
			break
		end
	end
end

function Canvas:setVisible(visible)
	self.visible = visible  -- TODO: use self.active = visible
	if not visible and self.parent then
		self.parent:dirty()
		-- TODO: set parent's lines to dirty for each line in self
	end
end

-- Push a layer to the top
function Canvas:raise()
	if self.parent and self.parent.children then
		for k, v in pairs(self.parent.children) do
			if v == self then
				table.insert(self.parent.children, table.remove(self.parent.children, k))
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
		fg = _rep(self.palette[fg] or self.palette[1], #text)
	end
	self:blit(x, y, text, bg, fg)
end

function Canvas:blit(x, y, text, bg, fg)
	if y > 0 and y <= #self.lines and x <= self.width then
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

			local line = self.lines[y]
			line.dirty = true
			line.text = replace(line.text, text)
			if fg then
				line.fg = replace(line.fg, fg)
			end
			if bg then
				line.bg = replace(line.bg, bg)
			end
		end
	end
end

function Canvas:writeLine(y, text, fg, bg)
	if y > 0 and y <= #self.lines then
		self.lines[y].dirty = true
		self.lines[y].text = text
		self.lines[y].fg = fg
		self.lines[y].bg = bg
	end
end

function Canvas:clearLine(y, bg, fg)
	fg = _rep(self.palette[fg or self.fg], self.width)
	bg = _rep(self.palette[bg or self.bg], self.width)
	self:writeLine(y, _rep(' ', self.width), fg, bg)
end

function Canvas:clear(bg, fg)
	local text = _rep(' ', self.width)
	fg = _rep(self.palette[fg or self.fg], self.width)
	bg = _rep(self.palette[bg or self.bg], self.width)
	for i = 1, #self.lines do
		self:writeLine(i, text, fg, bg)
	end
end

function Canvas:isDirty()
	for i = 1, #self.lines do
		if self.lines[i].dirty then
			return true
		end
	end
end

function Canvas:dirty(includingChildren)
	if self.lines then
		for i = 1, #self.lines do
			self.lines[i].dirty = true
		end

		if includingChildren and self.children then
			for _, child in pairs(self.children) do
				child:dirty(true)
			end
		end
	end
end

function Canvas:clean()
	for i = 1, #self.lines do
		self.lines[i].dirty = nil
	end
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

-- either render directly to the device
-- or use another canvas as a backing buffer
function Canvas:render(device, doubleBuffer)
	self.regions = Region.new(self.x, self.y, self.ex, self.ey)
	self:__renderLayers(device, { x = self.x - 1, y = self.y - 1 }, doubleBuffer)

	-- doubleBuffering to reduce the amount of
	-- setCursorPos, blits
	if doubleBuffer then
		--[[
		local drew = false
		local bg = _rep(2,   device.width)
		for k,v in pairs(device.lines) do
			if v.dirty then
				device.device.setCursorPos(device.x, device.y + k - 1)
				device.device.blit(v.text, v.fg, bg)
				drew = true
			end
		end
		if drew then
			local c = os.clock()
			repeat until os.clock()-c > .1
		end
		]]
		for k,v in pairs(device.lines) do
			if v.dirty then
				device.device.setCursorPos(device.x, device.y + k - 1)
				device.device.blit(v.text, v.fg, v.bg)
				v.dirty = false
			end
		end
	end
end

-- regions are comprised of absolute values that correspond to the output device.
-- canvases have coordinates relative to their parent.
-- canvas layer's stacking order is determined by the position within the array.
-- layers in the beginning of the array are overlayed by layers further down in
-- the array.
function Canvas:__renderLayers(device, offset, doubleBuffer)
	if self.children then
		for i = #self.children, 1, -1 do
			local canvas = self.children[i]
			if canvas.visible or canvas.enabled then
				-- get the area to render for this layer
				canvas.regions = Region.new(
					canvas.x + offset.x - (self.offx or 0),
					canvas.y + offset.y - (self.offy or 0),
					canvas.ex + offset.x - (self.offx or 0),
					canvas.ey + offset.y - (self.offy or 0))

				-- contain within parent
				canvas.regions:andRegion(self.regions)

				-- punch out this area from the parent's canvas
				self.regions:subRect(
					canvas.x + offset.x - (self.offx or 0),
					canvas.y + offset.y - (self.offy or 0),
					canvas.ex + offset.x - (self.offx or 0),
					canvas.ey + offset.y - (self.offy or 0))

				if #canvas.regions.region > 0 then
					canvas:__renderLayers(device, {
						x = canvas.x + offset.x - 1 - (self.offx or 0),
						y = canvas.y + offset.y - 1 - (self.offy or 0),
					}, doubleBuffer)
				end
				canvas.regions = nil
			end
		end
	end

	for _,region in ipairs(self.regions.region) do
		self:__blitRect(device,
			{ x = region[1] - offset.x,
			  y = region[2] - offset.y,
			  ex = region[3] - offset.x,
			  ey = region[4] - offset.y },
			{ x = region[1], y = region[2] },
			doubleBuffer)
	end
	self.regions = nil

	self:clean()
end

function Canvas:__blitRect(device, src, tgt, doubleBuffer)
	-- for visualizing updates on the screen
	--[[
	if Canvas.__visualize or self.visualize then
		local drew
		local t  = _rep(' ', src.ex-src.x + 1)
		local bg = _rep(2,   src.ex-src.x + 1)
		for i = 0, src.ey - src.y do
			local line = self.lines[src.y + i + (self.offy or 0)]
			if line and line.dirty then
				drew = true
				device.setCursorPos(tgt.x, tgt.y + i)
				device.blit(t, bg, bg)
			end
		end
		if drew then
			local c = os.clock()
			repeat until os.clock()-c > .03
		end
	end
	]]
	for i = 0, src.ey - src.y do
		local line = self.lines[src.y + i + (self.offy or 0)]
		if line and line.dirty then
			local t, fg, bg = line.text, line.fg, line.bg
			if src.x > 1 or src.ex < self.ex then
				t  = _sub(t, src.x, src.ex)
				fg = _sub(fg, src.x, src.ex)
				bg = _sub(bg, src.x, src.ex)
			end
			if doubleBuffer then
				Canvas.blit(device, tgt.x, tgt.y + i,
					t, bg, fg)
			else
				device.setCursorPos(tgt.x, tgt.y + i)
				device.blit(t, fg, bg)
			end
		end
	end
end

return Canvas

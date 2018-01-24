--
--	tek.lib.region
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--
-- Copyright 2008 - 2016 by the authors and contributors:
--
--  * Timm S. Muller <tmueller at schulze-mueller.de>
--  * Franciska Schulze <fschulze at schulze-mueller.de>
--  * Tobias Schwinger <tschwinger at isonews2.com>
--
-- https://opensource.org/licenses/MIT
--
-- Some comments have been removed to reduce file size, see:
-- https://github.com/technosaurus/tekui/blob/master/etc/region.lua
-- for the full source

local insert = table.insert
local ipairs = ipairs
local max = math.max
local min = math.min
local setmetatable = setmetatable
local unpack = unpack or table.unpack

local Region = { }
Region._VERSION = "Region 11.3"

Region.__index = Region

--	x0, y0, x1, y1 = Region.intersect(d1, d2, d3, d4, s1, s2, s3, s4):
--	Returns the coordinates of a rectangle where a rectangle specified by
--	the coordinates s1, s2, s3, s4 overlaps with the rectangle specified
--	by the coordinates d1, d2, d3, d4. The return value is '''nil''' if
--	the rectangles do not overlap.
function Region.intersect(d1, d2, d3, d4, s1, s2, s3, s4)
	if s3 >= d1 and s1 <= d3 and s4 >= d2 and s2 <= d4 then
		return max(s1, d1), max(s2, d2), min(s3, d3), min(s4, d4)
	end
end

--	insertrect: insert rect to table, merging with an existing one if possible
local function insertrect(d, s1, s2, s3, s4)
	for i = 1, min(4, #d) do
		local a = d[i]
		local a1, a2, a3, a4 = a[1], a[2], a[3], a[4]
		if a2 == s2 and a4 == s4 then
			if a3 + 1 == s1 then
				a[3] = s3
				return
			elseif a1 == s3 + 1 then
				a[1] = s1
				return
			end
		elseif a1 == s1 and a3 == s3 then
			if a4 + 1 == s2 then
				a[4] = s4
				return
			elseif a2 == s4 + 1 then
				a[2] = s2
				return
			end
		end
	end
	insert(d, 1, { s1, s2, s3, s4 })
end

--	cutrect: cut rect d into table of new rects, using rect s as a punch
local function cutrect(d1, d2, d3, d4, s1, s2, s3, s4)
	if not Region.intersect(d1, d2, d3, d4, s1, s2, s3, s4) then
		return { { d1, d2, d3, d4 } }
	end
	local r = { }
	if d1 < s1 then
		insertrect(r, d1, d2, s1 - 1, d4)
		d1 = s1
	end
	if d2 < s2 then
		insertrect(r, d1, d2, d3, s2 - 1)
		d2 = s2
	end
	if d3 > s3 then
		insertrect(r, s3 + 1, d2, d3, d4)
		d3 = s3
	end
	if d4 > s4 then
		insertrect(r, d1, s4 + 1, d3, d4)
	end
	return r
end

--	cutregion: cut region d, using s as a punch
local function cutregion(d, s1, s2, s3, s4)
	local r = { }
	for _, dr in ipairs(d) do
		local d1, d2, d3, d4 = dr[1], dr[2], dr[3], dr[4]
		for _, t in ipairs(cutrect(d1, d2, d3, d4, s1, s2, s3, s4)) do
			insertrect(r, t[1], t[2], t[3], t[4])
		end
	end
	return r
end

--	region = Region.new(r1, r2, r3, r4): Creates a new region from the given
--	coordinates.
function Region.new(r1, r2, r3, r4)
	if r1 then
		return setmetatable({ region = { { r1, r2, r3, r4 } } }, Region)
	end
	return setmetatable({ region = { } }, Region)
end

--	self = region:setRect(r1, r2, r3, r4): Resets an existing region
--	to the specified rectangle.
function Region:setRect(r1, r2, r3, r4)
	self.region = { { r1, r2, r3, r4 } }
	return self
end

--	region:orRect(r1, r2, r3, r4): Logical ''or''s a rectangle to a region
function Region:orRect(s1, s2, s3, s4)
	self.region = cutregion(self.region, s1, s2, s3, s4)
	insertrect(self.region, s1, s2, s3, s4)
end

--	region:orRegion(region): Logical ''or''s another region to a region
function Region:orRegion(s)
	for _, r in ipairs(s) do
		self:orRect(r[1], r[2], r[3], r[4])
	end
end

--	region:andRect(r1, r2, r3, r4): Logical ''and''s a rectange to a region
function Region:andRect(s1, s2, s3, s4)
	local r = { }
	for _, d in ipairs(self.region) do
		local t1, t2, t3, t4 =
			Region.intersect(d[1], d[2], d[3], d[4], s1, s2, s3, s4)
		if t1 then
			insertrect(r, t1, t2, t3, t4)
		end
	end
	self.region = r
end

--	region:xorRect(r1, r2, r3, r4): Logical ''xor''s a rectange to a region
function Region:xorRect(s1, s2, s3, s4)
	local r1 = { }
	local r2 = { { s1, s2, s3, s4 } }
	for _, d in ipairs(self.region) do
		local d1, d2, d3, d4 = d[1], d[2], d[3], d[4]
		for _, t in ipairs(cutrect(d1, d2, d3, d4, s1, s2, s3, s4)) do
			insertrect(r1, t[1], t[2], t[3], t[4])
		end
		r2 = cutregion(r2, d1, d2, d3, d4)
	end
	self.region = r1
	self:orRegion(r2)
end

--	self = region:subRect(r1, r2, r3, r4): Subtracts a rectangle from a region
function Region:subRect(s1, s2, s3, s4)
	local r1 = { }
	for _, d in ipairs(self.region) do
		local d1, d2, d3, d4 = d[1], d[2], d[3], d[4]
		for _, t in ipairs(cutrect(d1, d2, d3, d4, s1, s2, s3, s4)) do
			insertrect(r1, t[1], t[2], t[3], t[4])
		end
	end
	self.region = r1
	return self
end

--	region:getRect - gets an iterator on the rectangles in a region [internal]
function Region:getRects()
	local index = 0
	return function(object)
		index = index + 1
		if object[index] then
			return unpack(object[index])
		end
	end, self.region
end

--	success = region:checkIntersect(x0, y0, x1, y1): Returns a boolean
--	indicating whether a rectangle specified by its coordinates overlaps
--	with a region.
function Region:checkIntersect(s1, s2, s3, s4)
	for _, d in ipairs(self.region) do
		if Region.intersect(d[1], d[2], d[3], d[4], s1, s2, s3, s4) then
			return true
		end
	end
	return false
end

--	region:subRegion(region2): Subtracts {{region2}} from {{region}}.
function Region:subRegion(region)
	if region then
		for r1, r2, r3, r4 in region:getRects() do
			self:subRect(r1, r2, r3, r4)
		end
	end
end

--	region:andRegion(r): Logically ''and''s a region to a region
function Region:andRegion(s)
	local r = { }
	for _, s in ipairs(s.region) do
		for _, d in ipairs(self.region) do
			local t1, t2, t3, t4 =
				Region.intersect(d[1], d[2], d[3], d[4],
					s[1], s[2], s[3], s[4])
			if t1 then
				insertrect(r, t1, t2, t3, t4)
			end
		end
	end
	self.region = r
end

--	region:forEach(func, obj, ...): For each rectangle in a region, calls the
--	specified function according the following scheme:
--			func(obj, x0, y0, x1, y1, ...)
--	Extra arguments are passed through to the function.
function Region:forEach(func, obj, ...)
	for x0, y0, x1, y1 in self:getRects() do
		func(obj, x0, y0, x1, y1, ...) 
	end
end

--	region:shift(dx, dy): Shifts a region by delta x and y.
function Region:shift(dx, dy)
	for _, r in ipairs(self.region) do
		r[1] = r[1] + dx
		r[2] = r[2] + dy
		r[3] = r[3] + dx
		r[4] = r[4] + dy
	end
end

--	region:isEmpty(): Returns '''true''' if a region is empty.
function Region:isEmpty()
	return #self.region == 0
end

--	minx, miny, maxx, maxy = region:get(): Get region's min/max extents
function Region:get()
	if #self.region > 0 then
		local minx = 1000000 -- ui.HUGE
		local miny = 1000000
		local maxx = 0
		local maxy = 0
		for _, r in ipairs(self.region) do
			minx = min(minx, r[1])
			miny = min(miny, r[2])
			maxx = max(maxx, r[3])
			maxy = max(maxy, r[4])
		end
		return minx, miny, maxx, maxy
	end
end

return Region

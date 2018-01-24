local class = require('class')
local UI = require('ui')
local Event = require('event')
local Peripheral = require('peripheral')

--[[-- Glasses device --]]--
local Glasses = class()
function Glasses:init(args)

	local defaults = {
		backgroundColor = colors.black,
		textColor = colors.white,
		textScale = .5,
		backgroundOpacity = .5,
		multiplier = 2.6665,
--    multiplier = 2.333,
	}
	defaults.width, defaults.height = term.getSize()

	UI:setProperties(defaults, args)
	UI:setProperties(self, defaults)

	self.bridge = Peripheral.get({
		type = 'openperipheral_bridge',
		method = 'addBox',
	})
	self.bridge.clear()

	self.setBackgroundColor = function(...) end
	self.setTextColor = function(...) end

	self.t = { }
	for i = 1, self.height do
		self.t[i] = {
			text = string.rep(' ', self.width+1),
			--text = self.bridge.addText(0, 40+i*4, string.rep(' ', self.width+1), 0xffffff),
			bg = { },
			textFields = { },
		}
	end
end

function Glasses:setBackgroundBox(boxes, ax, bx, y, bgColor)
	local colors = {
		[ colors.black ] = 0x000000,
		[ colors.brown ] = 0x7F664C,
		[ colors.blue  ] = 0x253192,
		[ colors.red   ] = 0xFF0000,
		[ colors.gray  ] = 0x272727,
		[ colors.lime  ] = 0x426A0D,
		[ colors.green ] = 0x2D5628,
		[ colors.white ] = 0xFFFFFF
	}

	local function overlap(box, ax, bx)
		if bx < box.ax or ax > box.bx then
			return false
		end
		return true
	end

	for _,box in pairs(boxes) do
		if overlap(box, ax, bx) then 
			if box.bgColor == bgColor then
				ax = math.min(ax, box.ax)
				bx = math.max(bx, box.bx)
				box.ax = box.bx + 1
			elseif ax == box.ax then
				box.ax = bx + 1
			elseif ax > box.ax then
				if bx < box.bx then
					table.insert(boxes, { -- split
						ax = bx + 1,
						bx = box.bx,
						bgColor = box.bgColor
					})
					box.bx = ax - 1
					break
				else
					box.ax = box.bx + 1
				end
			elseif ax < box.ax then
				if bx > box.bx then
					box.ax = box.bx + 1 -- delete
				else
					box.ax = bx + 1
				end
			end
		end
	end
	if bgColor ~= colors.black then
		table.insert(boxes, {
			ax = ax,
			bx = bx,
			bgColor = bgColor
		})
	end

	local deleted
	repeat
		deleted = false
		for k,box in pairs(boxes) do
			if box.ax > box.bx then
				if box.box then
					box.box.delete()
				end
				table.remove(boxes, k)
				deleted = true
				break
			end
			if not box.box then
				box.box = self.bridge.addBox(
					math.floor(self.x + (box.ax - 1) * self.multiplier),
					self.y + y * 4,
					math.ceil((box.bx - box.ax + 1) * self.multiplier),
					4,
					colors[bgColor],
					self.backgroundOpacity)
			else
				box.box.setX(self.x + math.floor((box.ax - 1) * self.multiplier))
				box.box.setWidth(math.ceil((box.bx - box.ax + 1) * self.multiplier))
			end
		end
	until not deleted
end

function Glasses:write(x, y, text, bg)

	if x < 1 then
		error(' less ', 6)
	end
	if y <= #self.t then
		local line = self.t[y]
		local str = line.text
		str = str:sub(1, x-1) .. text .. str:sub(x + #text)
		self.t[y].text = str

		for _,tf in pairs(line.textFields) do
			tf.delete()
		end
		line.textFields = { }

		local function split(st)
			local words = { }
			local offset = 0
			while true do
				local b,e,w = st:find('(%S+)')
				if not b then
					break
				end
				table.insert(words, {
					offset = b + offset - 1,
					text = w,
				})
				offset = offset + e
				st = st:sub(e + 1)
			end
			return words
		end

		local words = split(str)
		for _,word in pairs(words) do
			local tf = self.bridge.addText(self.x + word.offset * self.multiplier,
																		 self.y+y*4, '', 0xffffff)
			tf.setScale(self.textScale)
			tf.setZ(1)
			tf.setText(word.text)
			table.insert(line.textFields, tf)
		end

		self:setBackgroundBox(line.bg, x, x + #text - 1, y, bg)
	end
end

function Glasses:clear(bg)
	for _,line in pairs(self.t) do
		for _,tf in pairs(line.textFields) do
			tf.delete()
		end
		line.textFields = { }
		line.text = string.rep(' ', self.width+1)
--    self.t[i].text.setText('')
	end
end

function Glasses:reset()
	self:clear()
	self.bridge.clear()
	self.bridge.sync()
end

function Glasses:sync()
	self.bridge.sync()
end

return Glasses

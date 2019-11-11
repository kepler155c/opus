local class = require('opus.class')
local Event = require('opus.event')
local UI    = require('opus.ui')
local Util  = require('opus.util')

local colors = _G.colors

UI.StatusBar = class(UI.Window)
UI.StatusBar.defaults = {
	UIElement = 'StatusBar',
	backgroundColor = colors.lightGray,
	textColor = colors.gray,
	height = 1,
	ey = -1,
}
function UI.StatusBar:adjustWidth()
	-- Can only have 1 adjustable width
	if self.columns then
		local w = self.width - #self.columns - 1
		for _,c in pairs(self.columns) do
			if c.width then
				c.cw = c.width  -- computed width
				w = w - c.width
			end
		end
		for _,c in pairs(self.columns) do
			if not c.width then
				c.cw = w
			end
		end
	end
end

function UI.StatusBar:resize()
	UI.Window.resize(self)
	self:adjustWidth()
end

function UI.StatusBar:setParent()
	UI.Window.setParent(self)
	self:adjustWidth()
end

function UI.StatusBar:setStatus(status)
	if self.values ~= status then
		self.values = status
		self:draw()
	end
end

function UI.StatusBar:setValue(name, value)
	if not self.values then
		self.values = { }
	end
	self.values[name] = value
end

function UI.StatusBar:getValue(name)
	if self.values then
		return self.values[name]
	end
end

function UI.StatusBar:timedStatus(status, timeout)
	self:write(2, 1, Util.widthify(status, self.width-2), self.backgroundColor)
	Event.on(timeout or 3, function()
		if self.enabled then
			self:draw()
			self:sync()
		end
	end)
end

function UI.StatusBar:getColumnWidth(name)
	local c = Util.find(self.columns, 'key', name)
	return c and c.cw
end

function UI.StatusBar:setColumnWidth(name, width)
	local c = Util.find(self.columns, 'key', name)
	if c then
		c.cw = width
	end
end

function UI.StatusBar:draw()
	if not self.values then
		self:clear()
	elseif type(self.values) == 'string' then
		self:write(1, 1, Util.widthify(' ' .. self.values, self.width))
	else
		local s = ''
		for _,c in ipairs(self.columns) do
			s = s .. ' ' .. Util.widthify(tostring(self.values[c.key] or ''), c.cw)
		end
		self:write(1, 1, Util.widthify(s, self.width))
	end
end

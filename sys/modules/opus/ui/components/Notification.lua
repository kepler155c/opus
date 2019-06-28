local class = require('opus.class')
local Event = require('opus.event')
local Sound = require('opus.sound')
local UI    = require('opus.ui')
local Util  = require('opus.util')

local colors = _G.colors

UI.Notification = class(UI.Window)
UI.Notification.defaults = {
	UIElement = 'Notification',
	backgroundColor = colors.gray,
	closeInd = UI.extChars and '\215' or '*',
	height = 3,
	timeout = 3,
	anchor = 'bottom',
}
function UI.Notification:draw()
end

function UI.Notification:enable()
end

function UI.Notification:error(value, timeout)
	self.backgroundColor = colors.red
	Sound.play('entity.villager.no', .5)
	self:display(value, timeout)
end

function UI.Notification:info(value, timeout)
	self.backgroundColor = colors.lightGray
	self:display(value, timeout)
end

function UI.Notification:success(value, timeout)
	self.backgroundColor = colors.green
	self:display(value, timeout)
end

function UI.Notification:cancel()
	if self.timer then
		Event.off(self.timer)
		self.timer = nil
	end

	if self.canvas then
		self.enabled = false
		self.canvas:removeLayer()
		self.canvas = nil
	end
end

function UI.Notification:display(value, timeout)
	self:cancel()
	self.enabled = true
	local lines = Util.wordWrap(value, self.width - 3)
	self.height = #lines

	if self.anchor == 'bottom' then
		self.y = self.parent.height - self.height + 1
		self.canvas = self:addLayer(self.backgroundColor, self.textColor)
		self:addTransition('expandUp', { ticks = self.height })
	else
		self.canvas = self:addLayer(self.backgroundColor, self.textColor)
		self.y = 1
	end
	self.canvas:setVisible(true)
	self:clear()
	for k,v in pairs(lines) do
		self:write(2, k, v)
	end

	timeout = timeout or self.timeout
	if timeout > 0 then
		self.timer = Event.onTimeout(timeout, function()
			self:cancel()
			self:sync()
		end)
	else
		self:write(self.width, 1, self.closeInd)
		self:sync()
	end
end

function UI.Notification:eventHandler(event)
	if event.type == 'mouse_click' then
		if event.x == self.width then
			self:cancel()
			return true
		end
	end
end

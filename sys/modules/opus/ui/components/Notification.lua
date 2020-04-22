local class = require('opus.class')
local Event = require('opus.event')
local Sound = require('opus.sound')
local UI    = require('opus.ui')
local Util  = require('opus.util')

UI.Notification = class(UI.Window)
UI.Notification.defaults = {
	UIElement = 'Notification',
	backgroundColor = 'gray',
	closeInd = UI.extChars and '\215' or '*',
	height = 3,
	timeout = 3,
	anchor = 'bottom',
}
function UI.Notification.draw()
end

function UI.Notification.enable()
end

function UI.Notification:error(value, timeout)
	self.backgroundColor = 'red'
	Sound.play('entity.villager.no', .5)
	self:display(value, timeout)
end

function UI.Notification:info(value, timeout)
	self.backgroundColor = 'lightGray'
	self:display(value, timeout)
end

function UI.Notification:success(value, timeout)
	self.backgroundColor = 'green'
	self:display(value, timeout)
end

function UI.Notification:cancel()
	if self.timer then
		Event.off(self.timer)
		self.timer = nil
	end

	self:disable()
end

function UI.Notification:display(value, timeout)
	local lines = Util.wordWrap(value, self.width - 3)

	self.enabled = true
	self.height = #lines

	if self.anchor == 'bottom' then
		self.y = self.parent.height - self.height + 1
		self:addTransition('expandUp', { ticks = self.height })
	else
		self.y = 1
	end

	self:reposition(self.x, self.y, self.width, self.height)
	self:raise()
	self:clear()
	for k,v in pairs(lines) do
		self:write(2, k, v)
	end
	self:write(self.width, 1, self.closeInd)

	if self.timer then
		Event.off(self.timer)
		self.timer = nil
	end

	timeout = timeout or self.timeout
	if timeout > 0 then
		self.timer = Event.onTimeout(timeout, function()
			self:cancel()
			self:sync()
		end)
	else
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

function UI.Notification.example()
	return UI.Window {
		notify1 = UI.Notification {
			anchor = 'top',
		},
		notify2 = UI.Notification { },
		button1 = UI.Button {
			x = 2, y = 3,
			text = 'example 1',
			event = 'test_success',
		},
		button2 = UI.Button {
			x = 2, y = 5,
			text = 'example 2',
			event = 'test_error',
		},
		eventHandler = function (self, event)
			if event.type == 'test_success' then
				self.notify1:success('Example text')
			elseif event.type == 'test_error' then
				self.notify2:error([[Example text test test
test test test test test
test test test]], 0)
			end
		end,
	}
end

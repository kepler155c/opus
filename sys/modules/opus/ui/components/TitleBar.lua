local class = require('opus.class')
local UI    = require('opus.ui')

UI.TitleBar = class(UI.Window)
UI.TitleBar.defaults = {
	UIElement = 'TitleBar',
	height = 1,
	title = '',
	frameChar = UI.extChars and '\140' or '-',
	closeInd = UI.extChars and '\215' or '*',
}
function UI.TitleBar:draw()
	self:fillArea(2, 1, self.width - 2, 1, self.frameChar)
	self:centeredWrite(1, string.format(' %s ', self.title))
	if self.previousPage or self.event then
		self:write(self.width - 1, 1, ' ' .. self.closeInd)
	end
end

function UI.TitleBar:eventHandler(event)
	if event.type == 'mouse_click' then
		if (self.previousPage or self.event) and event.x == self.width then
			if self.event then
				self:emit({ type = self.event, element = self })
			elseif type(self.previousPage) == 'string' or
				 type(self.previousPage) == 'table' then
				UI:setPage(self.previousPage)
			else
				UI:setPreviousPage()
			end
			return true
		end

	elseif event.type == 'mouse_down' then
		self.anchor = { x = event.x, y = event.y, ox = self.parent.x, oy = self.parent.y, h = self.parent.height }

	elseif event.type == 'mouse_drag' then
		if self.expand == 'height' then
			local d = event.dy
			if self.anchor.h - d > 0 and self.anchor.oy + d > 0 then
				self.parent:reposition(self.parent.x, self.anchor.oy + event.dy, self.width, self.anchor.h - d)
			end

		elseif self.moveable then
			local d = event.dy
			if self.anchor.oy + d > 0 and self.anchor.oy + d <= self.parent.parent.height then
				self.parent:move(self.anchor.ox + event.dx, self.anchor.oy + event.dy)
			end
		end
	end
end

function UI.TitleBar.example()
	return UI.Window {
		win1 = UI.Window {
			x = 9, y = 2, ex = -7, ey = -3,
			backgroundColor = 'green',
			titleBar = UI.TitleBar {
				title = 'A really, really, really long title',  moveable = true,
			},
			button1 = UI.Button {
				x = 2, y = 3,
				text = 'Press',
			},
			focus = function (self)
				self:raise()
			end,
		},
		win2 = UI.Window {
			x = 7, y = 3, ex = -9, ey = -2,
			backgroundColor = 'orange',
			titleBar = UI.TitleBar {
				title = 'test', moveable = true,
				event = 'none',
			},
			button1 = UI.Button {
				x = 2, y = 3,
				text = 'Press',
			},
			focus = UI.Window.raise,
		},
		draw = function(self, isBG)
			for i = 1, self.height do
				self:write(1, i, self.filler or '')
			end
			if not isBG then
				for _,v in pairs(self.children) do
					v:draw()
				end
			end
		end,
		enable = function (self)
			require('opus.event').onInterval(.5, function()
				self.filler = string.rep(string.char(math.random(33, 126)), self.width)
				self:draw(true)
				self:sync()
			end)
			UI.Window.enable(self)
		end
	}
end

local class = require('opus.class')
local UI    = require('opus.ui')
local Util  = require('opus.util')

UI.DropMenu = class(UI.MenuBar)
UI.DropMenu.defaults = {
	UIElement = 'DropMenu',
	backgroundColor = 'white',
	buttonClass = 'DropMenuItem',
}
function UI.DropMenu:layout()
	UI.MenuBar.layout(self)

	local maxWidth = 1
	for y,child in ipairs(self.children) do
		child.x = 1
		child.y = y
		if #(child.text or '') > maxWidth then
			maxWidth = #child.text
		end
	end
	for _,child in ipairs(self.children) do
		child.width = maxWidth + 2
		if child.spacer then
			child.inactive = true
			child.text = string.rep('-', child.width - 2)
		end
	end

	self.height = #self.children + 1
	self.width = maxWidth + 2

	if self.x + self.width > self.parent.width then
		self.x = self.parent.width - self.width + 1
	end

	self:reposition(self.x, self.y, self.width, self.height)
end

function UI.DropMenu:enable()
	local menuBar = self.parent:find(self.menuUid)
	local hasActive

	for _,c in pairs(self.children) do
		if not c.spacer and menuBar then
			c.inactive = not menuBar:getActive(c)
		end
		if not c.inactive then
			hasActive = true
		end
	end

	-- jump through a lot of hoops if all selections are inactive
	-- there's gotta be a better way
	-- lots of exception code just to handle drop menus
	self.focus = not hasActive and function() end

	UI.Window.enable(self)
	if self.focus then
		self:setFocus(self)
	else
		self:focusFirst()
	end
	self:draw()
end

function UI.DropMenu:disable()
	UI.Window.disable(self)
	self:remove()
end

function UI.DropMenu:eventHandler(event)
	if event.type == 'focus_lost' and self.enabled then
		if not (Util.contains(self.children, event.focused) or event.focused == self) then
			self:disable()
		end
	elseif event.type == 'mouse_out' and self.enabled then
		self:disable()
		self:setFocus(self.parent:find(self.lastFocus))
	else
		return UI.MenuBar.eventHandler(self, event)
	end
	return true
end

function UI.DropMenu.example()
	return UI.MenuBar {
		buttons = {
			{ text = 'File', dropdown = {
					{ text = 'Run',            event = 'run' },
					{ text = 'Shell        s', event = 'shell'  },
					{ spacer = true },
					{ text = 'Quit        ^q', event = 'quit'   },
			} },
			{ text = 'Edit', dropdown = {
				{ text = 'Copy',           event = 'run' },
				{ text = 'Paste        s', event = 'shell'  },
			} },
			{ text = '\187',
				x = -3,
				dropdown = {
					{ text = 'Associations', event = 'associate' },
			} },
		}
	}
end

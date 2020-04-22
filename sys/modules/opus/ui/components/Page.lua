local class  = require('opus.class')
local UI     = require('opus.ui')
local Util   = require('opus.util')

UI.Page = class(UI.Window)
UI.Page.defaults = {
	UIElement = 'Page',
	accelerators = {
		down = 'focus_next',
		scroll_down = 'focus_next',
		enter = 'focus_next',
		tab = 'focus_next',
		['shift-tab' ] = 'focus_prev',
		up = 'focus_prev',
		scroll_up = 'focus_prev',
	},
	backgroundColor = 'primary',
	textColor = 'white',
}
function UI.Page:postInit()
	self.parent = self.parent or UI.term
	self.__target = self
end

function UI.Page:sync()
	if self.enabled then
		self:checkFocus()
		self.parent:setCursorBlink(self.focused and self.focused.cursorBlink)
		self.parent:sync()
	end
end

function UI.Page:capture(child)
	self.__target = child
end

function UI.Page:release(child)
	if self.__target == child then
		self.__target = self
	end
end

function UI.Page:pointToChild(x, y)
	if self.__target == self then
		return UI.Window.pointToChild(self, x, y)
	end

	local function getPosition(element)
		local x, y = 1, 1
		repeat
			x = element.x + x - 1
			y = element.y + y - 1
			element = element.parent
		until not element
		return x, y
	end

	local absX, absY = getPosition(self.__target)
	return self.__target:pointToChild(x - absX + self.__target.x, y - absY + self.__target.y)
end

function UI.Page:getFocusables()
	if self.__target == self or not self.__target.modal then
		return UI.Window.getFocusables(self)
	end
	return self.__target:getFocusables()
end

function UI.Page:getFocused()
	return self.focused
end

function UI.Page:focusPrevious()
	local function getPreviousFocus(focused)
		local focusables = self:getFocusables()
		local k = Util.contains(focusables, focused)
		if k then
			if k > 1 then
				return focusables[k - 1]
			end
			return focusables[#focusables]
		end
	end

	local focused = getPreviousFocus(self.focused)
	if focused then
		self:setFocus(focused)
	end
end

function UI.Page:focusNext()
	local function getNextFocus(focused)
		local focusables = self:getFocusables()
		local k = Util.contains(focusables, focused)
		if k then
			if k < #focusables then
				return focusables[k + 1]
			end
			return focusables[1]
		end
	end

	local focused = getNextFocus(self.focused)
	if focused then
		self:setFocus(focused)
	end
end

function UI.Page:setFocus(child)
	if not child or not child.focus then
		return
	end

	if self.focused and self.focused ~= child then
		self.focused.focused = false
		self.focused:focus()
		self.focused:emit({ type = 'focus_lost', focused = child, unfocused = self.focused })
	end

	self.focused = child
	if not child.focused then
		child.focused = true
		child:emit({ type = 'focus_change', focused = child })
	end

	child:focus()
end

function UI.Page:checkFocus()
	if not self.focused or not self.focused.enabled then
		self.__target:focusFirst()
	end
end

function UI.Page:eventHandler(event)
	if self.focused then
		if event.type == 'focus_next' then
			self:focusNext()
			return true
		elseif event.type == 'focus_prev' then
			self:focusPrevious()
			return true
		end
	end
end

local Canvas = require('opus.ui.canvas')
local class  = require('opus.class')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local colors = _G.colors

-- need to add offsets to this test
local function getPosition(element)
	local x, y = 1, 1
	repeat
		x = element.x + x - 1
		y = element.y + y - 1
		element = element.parent
	until not element
	return x, y
end

UI.Page = class(UI.Window)
UI.Page.defaults = {
	UIElement = 'Page',
	accelerators = {
		down = 'focus_next',
		enter = 'focus_next',
		tab = 'focus_next',
		['shift-tab' ] = 'focus_prev',
		up = 'focus_prev',
	},
	backgroundColor = colors.cyan,
	textColor = colors.white,
}
function UI.Page:postInit()
	self.parent = self.parent or UI.defaultDevice
	self.__target = self
	self.canvas = Canvas({
		x = 1, y = 1, width = self.parent.width, height = self.parent.height,
		isColor = self.parent.isColor,
	})
	self.canvas:clear(self.backgroundColor, self.textColor)
end

function UI.Page:enable()
	self.canvas.visible = true
	UI.Window.enable(self)

	if not self.focused or not self.focused.enabled then
		self:focusFirst()
	end
end

function UI.Page:disable()
	self.canvas.visible = false
	UI.Window.disable(self)
end

function UI.Page:sync()
	if self.enabled then
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
	x = x + self.offx - self.x + 1
	y = y + self.offy - self.y + 1
--[[
	-- this is supposed to fix when there are multiple sub canvases
	local absX, absY = getPosition(self.__target)
	if self.__target.canvas then
		x = x - (self.__target.canvas.x - self.__target.x)
		y = y - (self.__target.canvas.y - self.__target.y)
		_syslog({'raw', self.__target.canvas.y, self.__target.y})
	end
	]]
	return self.__target:pointToChild(x, y)
end

function UI.Page:getFocusables()
	if self.__target == self or self.__target.pageType ~= 'modal' then
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
		--self:emit({ type = 'focus_change', focused = child })
	end

	child:focus()
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

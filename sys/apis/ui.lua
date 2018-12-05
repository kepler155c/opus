local Canvas     = require('ui.canvas')
local class      = require('class')
local Event      = require('event')
local Input      = require('input')
local Peripheral = require('peripheral')
local Sound      = require('sound')
local Transition = require('ui.transition')
local Util       = require('util')

local _rep       = string.rep
local _sub       = string.sub
local colors     = _G.colors
local device     = _G.device
local fs         = _G.fs
local os         = _G.os
local term       = _G.term
local window     = _G.window

--[[
	Using the shorthand window definition, elements are created from
	the bottom up. Once reaching the top, setParent is called top down.

	On :init(), elements do not know the parent or can calculate sizing.
]]

local function safeValue(v)
	local t = type(v)
	if t == 'string' or t == 'number' then
		return v
	end
	return tostring(v)
end

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

--[[-- Top Level Manager --]]--
local Manager = class()
function Manager:init()
	local function keyFunction(event, code, held)
		local ie = Input:translate(event, code, held)

		if ie and self.currentPage then
			local target = self.currentPage.focused or self.currentPage
			self:inputEvent(target,
				{ type = 'key', key = ie.code == 'char' and ie.ch or ie.code, element = target })
			self.currentPage:sync()
		end
	end

	local handlers = {
		char = keyFunction,
		key_up = keyFunction,
		key = keyFunction,

		term_resize = function(_, side)
			if self.currentPage then
				-- the parent doesn't have any children set...
				-- that's why we have to resize both the parent and the current page
				-- kinda makes sense
				if self.currentPage.parent.device.side == side then
					self.currentPage.parent:resize()

					self.currentPage:resize()
					self.currentPage:draw()
					self.currentPage:sync()
				end
			end
		end,

		mouse_scroll = function(_, direction, x, y)
			if self.currentPage then
				local event = self.currentPage:pointToChild(x, y)
				local directions = {
					[ -1 ] = 'up',
					[  1 ] = 'down'
				}
				-- revisit - should send out scroll_up and scroll_down events
				-- let the element convert them to up / down
				self:inputEvent(event.element,
					{ type = 'key', key = directions[direction] })
				self.currentPage:sync()
			end
		end,

		-- this should be moved to the device !
		monitor_touch = function(_, side, x, y)
			Input:translate('mouse_click', 1, x, y)
			local ie = Input:translate('mouse_up', 1, x, y)
			if self.currentPage then
				if self.currentPage.parent.device.side == side then
					self:click(ie.code, 1, x, y)
				end
			end
		end,

		mouse_click = function(_, button, x, y)
			Input:translate('mouse_click', button, x, y)

			if self.currentPage then
				if not self.currentPage.parent.device.side then
					local event = self.currentPage:pointToChild(x, y)
					if event.element.focus and not event.element.inactive then
						self.currentPage:setFocus(event.element)
						self.currentPage:sync()
					end
				end
			end
		end,

		mouse_up = function(_, button, x, y)
			local ie = Input:translate('mouse_up', button, x, y)

			if ie.code == 'control-shift-mouse_click' then -- hack
				local event = self.currentPage:pointToChild(x, y)
				_ENV.multishell.openTab({
					path = 'sys/apps/Lua.lua',
					args = { event.element },
					focused = true })

			elseif ie and self.currentPage then
				--if not self.currentPage.parent.device.side then
					self:click(ie.code, button, x, y)
				--end
			end
		end,

		mouse_drag = function(_, button, x, y)
			local ie = Input:translate('mouse_drag', button, x, y)
			if ie and self.currentPage then
				local event = self.currentPage:pointToChild(x, y)
				event.type = ie.code
				self:inputEvent(event.element, event)
				self.currentPage:sync()
			end
		end,

		paste = function(_, text)
			Input:translate('paste')
			self:emitEvent({ type = 'paste', text = text })
			self.currentPage:sync()
		end,
	}

	-- use 1 handler to single thread all events
	Event.on({
		'char', 'key_up', 'key', 'term_resize',
		'mouse_scroll', 'monitor_touch', 'mouse_click',
		'mouse_up', 'mouse_drag', 'paste' },
		function(event, ...)
			handlers[event](event, ...)
		end)
end

function Manager:configure(appName, ...)
	local options = {
		device     = { arg = 'd', type = 'string',
									 desc = 'Device type' },
		textScale  = { arg = 't', type = 'number',
									 desc = 'Text scale' },
	}
	local defaults = Util.loadTable('usr/config/' .. appName) or { }
	if not defaults.device then
		defaults.device = { }
	end

	Util.getOptions(options, { ... }, true)
	local optionValues = {
		name = options.device.value,
		textScale = options.textScale.value,
	}

	Util.merge(defaults.device, optionValues)

	if defaults.device.name then

		local dev

		if defaults.device.name == 'terminal' then
			dev = term.current()
		else
			dev = Peripheral.lookup(defaults.device.name) --- device[defaults.device.name]
		end

		if not dev then
			error('Invalid display device')
		end
		self:setDefaultDevice(self.Device({
			device = dev,
			textScale = defaults.device.textScale,
		}))
	end

	if defaults.theme then
		for k,v in pairs(defaults.theme) do
			if self[k] and self[k].defaults then
				Util.merge(self[k].defaults, v)
			end
		end
	end
end

function Manager:disableEffects()
	self.defaultDevice.effectsEnabled = false
end

function Manager:loadTheme(filename)
	if fs.exists(filename) then
		local theme, err = Util.loadTable(filename)
		if not theme then
			error(err)
		end
		for k,v in pairs(theme) do
			if self[k] and self[k].defaults then
				Util.merge(self[k].defaults, v)
			end
		end
	end
end

function Manager:emitEvent(event)
	if self.currentPage and self.currentPage.focused then
		return self.currentPage.focused:emit(event)
	end
end

function Manager:inputEvent(parent, event)
	while parent do
		if parent.accelerators then
			local acc = parent.accelerators[event.key]
			if acc then
				if parent:emit({ type = acc, element = parent }) then
					return true
				end
			end
		end
		if parent.eventHandler then
			if parent:eventHandler(event) then
				return true
			end
		end
		parent = parent.parent
	end
end

function Manager:click(code, button, x, y)
	if self.currentPage then

		local target = self.currentPage

		-- need to add offsets into this check
		--[[
		if x < target.x or y < target.y or
			x > target.x + target.width - 1 or
			y > target.y + target.height - 1 then
			target:emit({ type = 'mouse_out' })

			target = self.currentPage
		end
		--]]

		local clickEvent = target:pointToChild(x, y)

		if code == 'mouse_doubleclick' then
			if self.doubleClickElement ~= clickEvent.element then
				return
			end
		else
			self.doubleClickElement = clickEvent.element
		end

		clickEvent.button = button
		clickEvent.type = code
		clickEvent.key = code

		if clickEvent.element.focus then
			self.currentPage:setFocus(clickEvent.element)
		end
		if not self:inputEvent(clickEvent.element, clickEvent) then
			--[[
			if button == 3 then
				-- if the double-click was not captured
				-- send through a single-click
				clickEvent.button = 1
				clickEvent.type = events[1]
				clickEvent.key = events[1]
				self:inputEvent(clickEvent.element, clickEvent)
			end
			]]
		end

		self.currentPage:sync()
	end
end

function Manager:setDefaultDevice(dev)
	self.defaultDevice = dev
	self.term = dev
end

function Manager:addPage(name, page)
	if not self.pages then
		self.pages = { }
	end
	self.pages[name] = page
end

function Manager:setPages(pages)
	self.pages = pages
end

function Manager:getPage(pageName)
	local page = self.pages[pageName]

	if not page then
		error('UI:getPage: Invalid page: ' .. tostring(pageName), 2)
	end

	return page
end

function Manager:setPage(pageOrName, ...)
	local page = pageOrName

	if type(pageOrName) == 'string' then
		page = self.pages[pageOrName] or error('Invalid page: ' .. pageOrName)
	end

	if page == self.currentPage then
		page:draw()
	else
		local needSync
		if self.currentPage then
			if self.currentPage.focused then
				self.currentPage.focused.focused = false
				self.currentPage.focused:focus()
			end
			self.currentPage:disable()
			page.previousPage = self.currentPage
		else
			needSync = true
		end
		self.currentPage = page
		self.currentPage:clear(page.backgroundColor)
		page:enable(...)
		page:draw()
		if self.currentPage.focused then
			self.currentPage.focused.focused = true
			self.currentPage.focused:focus()
		end
		if needSync then
			page:sync() -- first time a page has been set
		end
	end
end

function Manager:getCurrentPage()
	return self.currentPage
end

function Manager:setPreviousPage()
	if self.currentPage.previousPage then
		local previousPage = self.currentPage.previousPage.previousPage
		self:setPage(self.currentPage.previousPage)
		self.currentPage.previousPage = previousPage
	end
end

function Manager:getDefaults(element, args)
	local defaults = Util.deepCopy(element.defaults)
	if args then
		Manager:mergeProperties(defaults, args)
	end
	return defaults
end

function Manager:mergeProperties(obj, args)
	if args then
		for k,v in pairs(args) do
			if k == 'accelerators' then
				if obj.accelerators then
					Util.merge(obj.accelerators, args.accelerators)
				else
					obj[k] = v
				end
			else
				obj[k] = v
			end
		end
	end
end

function Manager:pullEvents(...)
	Event.pullEvents(...)
	self.term:reset()
end

function Manager:exitPullEvents()
	Event.exitPullEvents()
end

local UI = Manager()

--[[-- Basic drawable area --]]--
UI.Window = class()
UI.Window.uid = 1
UI.Window.defaults = {
	UIElement = 'Window',
	x = 1,
	y = 1,
	-- z = 0, -- eventually...
	offx = 0,
	offy = 0,
	cursorX = 1,
	cursorY = 1,
}
function UI.Window:init(args)
	-- merge defaults for all subclasses
	local defaults = args
	local m = getmetatable(self)  -- get the class for this instance
	repeat
		defaults = UI:getDefaults(m, defaults)
		m = m._base
	until not m
	UI:mergeProperties(self, defaults)

	-- each element has a unique ID
	self.uid = UI.Window.uid
	UI.Window.uid = UI.Window.uid + 1

	-- at this time, the object has all the properties set

	-- postInit is a special constructor. the element does not need to implement
	-- the method. But we need to guarantee that each subclass which has this
	-- method is called.
	m = self
	local lpi
	repeat
		if m.postInit and m.postInit ~= lpi then
			m.postInit(self)
			lpi = m.postInit
		end
		m = m._base
	until not m
end

function UI.Window:postInit()
	if self.parent then
		-- this will cascade down the whole tree of elements starting at the
		-- top level window (which has a device as a parent)
		self:setParent()
	end
end

function UI.Window:initChildren()
	local children = self.children

	-- insert any UI elements created using the shorthand
	-- window definition into the children array
	for k,child in pairs(self) do
		if k ~= 'parent' then -- reserved
			if type(child) == 'table' and child.UIElement and not child.parent then
				if not children then
					children = { }
				end
				table.insert(children, child)
			end
		end
	end
	if children then
		for _,child in pairs(children) do
			if not child.parent then
				child.parent = self
				child:setParent()
				-- child:reposition() -- maybe
				if self.enabled then
					child:enable()
				end
			end
		end
		self.children = children
	end
end

local function setSize(self)
	if self.x < 0 then
		self.x = self.parent.width + self.x + 1
	end
	if self.y < 0 then
		self.y = self.parent.height + self.y + 1
	end

	if self.ex then
		local ex = self.ex
		if self.ex <= 1 then
			ex = self.parent.width + self.ex + 1
		end
		if self.width then
			self.x = ex - self.width + 1
		else
			self.width = ex - self.x + 1
		end
	end
	if self.ey then
		local ey = self.ey
		if self.ey <= 1 then
			ey = self.parent.height + self.ey + 1
		end
		if self.height then
			self.y = ey - self.height + 1
		else
			self.height = ey - self.y + 1
		end
	end

	if not self.width then
		self.width = self.parent.width - self.x + 1
	end
	if not self.height then
		self.height = self.parent.height - self.y + 1
	end
end

-- bad name... should be called something like postInit
-- normally used to determine sizes since the parent is
-- only known at this point
function UI.Window:setParent()
	self.oh, self.ow = self.height, self.width
	self.ox, self.oy = self.x, self.y

	setSize(self)

	self:initChildren()
end

function UI.Window:resize()
	self.height, self.width = self.oh, self.ow
	self.x, self.y = self.ox, self.oy

	setSize(self)

	if self.children then
		for _,child in ipairs(self.children) do
			child:resize()
		end
	end
end

function UI.Window:add(children)
	UI:mergeProperties(self, children)
	self:initChildren()
end

function UI.Window:getCursorPos()
	return self.cursorX, self.cursorY
end

function UI.Window:setCursorPos(x, y)
	self.cursorX = x
	self.cursorY = y
	self.parent:setCursorPos(self.x + x - 1, self.y + y - 1)
end

function UI.Window:setCursorBlink(blink)
	self.parent:setCursorBlink(blink)
end

function UI.Window:draw()
	self:clear(self.backgroundColor)
	if self.children then
		for _,child in pairs(self.children) do
			if child.enabled then
				child:draw()
			end
		end
	end
end

function UI.Window:sync()
	if self.parent then
		self.parent:sync()
	end
end

function UI.Window:enable()
	self.enabled = true
	if self.children then
		for _,child in pairs(self.children) do
			child:enable()
		end
	end
end

function UI.Window:disable()
	self.enabled = false
	if self.children then
		for _,child in pairs(self.children) do
			child:disable()
		end
	end
end

function UI.Window:setTextScale(textScale)
	self.textScale = textScale
	self.parent:setTextScale(textScale)
end

function UI.Window:clear(bg, fg)
	if self.canvas then
		self.canvas:clear(bg or self.backgroundColor, fg or self.textColor)
	else
		self:clearArea(1 + self.offx, 1 + self.offy, self.width, self.height, bg)
	end
end

function UI.Window:clearLine(y, bg)
	self:write(1, y, _rep(' ', self.width), bg)
end

function UI.Window:clearArea(x, y, width, height, bg)
	if width > 0 then
		local filler = _rep(' ', width)
		for i = 0, height - 1 do
			self:write(x, y + i, filler, bg)
		end
	end
end

function UI.Window:write(x, y, text, bg, tc)
	bg = bg or self.backgroundColor
	tc = tc or self.textColor
	x = x - self.offx
	y = y - self.offy
	if y <= self.height and y > 0 then
		if self.canvas then
			self.canvas:write(x, y, text, bg, tc)
		else
			self.parent:write(
				self.x + x - 1, self.y + y - 1, tostring(text), bg, tc)
		end
	end
end

function UI.Window:centeredWrite(y, text, bg, fg)
	if #text >= self.width then
		self:write(1, y, text, bg, fg)
	else
		local space = math.floor((self.width-#text) / 2)
		local filler = _rep(' ', space + 1)
		local str = _sub(filler, 1, space) .. text
		str = str .. _sub(filler, self.width - #str + 1)
		self:write(1, y, str, bg, fg)
	end
end

function UI.Window:print(text, bg, fg)
	local marginLeft = self.marginLeft or 0
	local marginRight = self.marginRight or 0
	local width = self.width - marginLeft - marginRight

	local function nextWord(line, cx)
		local result = { line:find("(%w+)", cx) }
		if #result > 1 and result[2] > cx then
			return _sub(line, cx, result[2] + 1)
		elseif #result > 0 and result[1] == cx then
			result = { line:find("(%w+)", result[2]) }
			if #result > 0 then
				return _sub(line, cx, result[1] + 1)
			end
		end
		if cx <= #line then
			return _sub(line, cx, #line)
		end
	end

	local function pieces(f, bg, fg)
		local pos = 1
		local t = { }
		while true do
			local s = string.find(f, '\027', pos, true)
			if not s then
				break
			end
			if pos < s then
				table.insert(t, _sub(f, pos, s - 1))
			end
			local seq = _sub(f, s)
			seq = seq:match("\027%[([%d;]+)m")
			local e = { }
			for color in string.gmatch(seq, "%d+") do
				color = tonumber(color)
				if color == 0 then
					e.fg = fg
					e.bg = bg
				elseif color > 20 then
					e.bg = 2 ^ (color - 21)
				else
					e.fg = 2 ^ (color - 1)
				end
			end
			table.insert(t, e)
			pos = s + #seq + 3
		end
		if pos <= #f then
			table.insert(t, _sub(f, pos))
		end
		return t
	end

	local lines = Util.split(text)
	for k,line in pairs(lines) do
		local fragments = pieces(line, bg, fg)
		for _, fragment in ipairs(fragments) do
			local lx = 1
			if type(fragment) == 'table' then -- ansi sequence
				fg = fragment.fg
				bg = fragment.bg
			else
				while true do
					local word = nextWord(fragment, lx)
					if not word then
						break
					end
					local w = word
					if self.cursorX + #word > width then
						self.cursorX = marginLeft + 1
						self.cursorY = self.cursorY + 1
						w = word:gsub('^ ', '')
					end
					self:write(self.cursorX, self.cursorY, w, bg, fg)
					self.cursorX = self.cursorX + #w
					lx = lx + #word
				end
			end
		end
		if lines[k + 1] then
			self.cursorX = marginLeft + 1
			self.cursorY = self.cursorY + 1
		end
	end

	return self.cursorX, self.cursorY
end

function UI.Window:setFocus(focus)
	if self.parent then
		self.parent:setFocus(focus)
	end
end

function UI.Window:capture(child)
	if self.parent then
		self.parent:capture(child)
	end
end

function UI.Window:release(child)
	if self.parent then
		self.parent:release(child)
	end
end

function UI.Window:pointToChild(x, y)
	x = x + self.offx - self.x + 1
	y = y + self.offy - self.y + 1
	if self.children then
		for _,child in pairs(self.children) do
			if child.enabled and not child.inactive and
				 x >= child.x and x < child.x + child.width and
				 y >= child.y and y < child.y + child.height then
				local c = child:pointToChild(x, y)
				if c then
					return c
				end
			end
		end
	end
	return {
		element = self,
		x = x,
		y = y
	}
end

function UI.Window:getFocusables()
	local focusable = { }

	local function focusSort(a, b)
		if a.y == b.y then
			return a.x < b.x
		end
		return a.y < b.y
	end

	local function getFocusable(parent, x, y)
		for _,child in Util.spairs(parent.children, focusSort) do
			if child.enabled and child.focus and not child.inactive then
				table.insert(focusable, child)
			end
			if child.children then
				getFocusable(child, child.x + x, child.y + y)
			end
		end
	end

	if self.children then
		getFocusable(self, self.x, self.y)
	end

	return focusable
end

function UI.Window:focusFirst()
	local focusables = self:getFocusables()
	local focused = focusables[1]
	if focused then
		self:setFocus(focused)
	end
end

function UI.Window:refocus()
	local el = self
	while el do
		local focusables = el:getFocusables()
		if focusables[1] then
			self:setFocus(focusables[1])
			break
		end
		el = el.parent
	end
end

function UI.Window:scrollIntoView()
	local parent = self.parent

	if self.x <= parent.offx then
		parent.offx = math.max(0, self.x - 1)
		parent:draw()
	elseif self.x + self.width > parent.width + parent.offx then
		parent.offx = self.x + self.width - parent.width - 1
		parent:draw()
	end

	if self.y <= parent.offy then
		parent.offy = math.max(0, self.y - 1)
		parent:draw()
	elseif self.y + self.height > parent.height + parent.offy then
		parent.offy = self.y + self.height - parent.height - 1
		parent:draw()
	end
end

function UI.Window:getCanvas()
	local el = self
	repeat
		if el.canvas then
			return el.canvas
		end
		el = el.parent
	until not el
end

function UI.Window:addLayer(bg, fg)
	local canvas = self:getCanvas()
	canvas = canvas:addLayer(self, bg, fg)
	canvas:clear(bg or self.backgroundColor, fg or self.textColor)
	return canvas
end

function UI.Window:addTransition(effect, args)
	if self.parent then
		args = args or { }
		if not args.x then -- not good
			args.x, args.y = getPosition(self)
			args.width = self.width
			args.height = self.height
		end

		args.canvas = args.canvas or self.canvas
		self.parent:addTransition(effect, args)
	end
end

function UI.Window:emit(event)
	local parent = self
	while parent do
		if parent.eventHandler then
			if parent:eventHandler(event) then
				return true
			end
		end
		parent = parent.parent
	end
end

function UI.Window:find(uid)
	if self.children then
		return Util.find(self.children, 'uid', uid)
	end
end

function UI.Window:eventHandler(event)
	return false
end

--[[-- Terminal for computer / advanced computer / monitor --]]--
UI.Device = class(UI.Window)
UI.Device.defaults = {
	UIElement = 'Device',
	backgroundColor = colors.black,
	textColor = colors.white,
	textScale = 1,
	effectsEnabled = true,
}
function UI.Device:postInit()
	self.device = self.device or term.current()

	if self.deviceType then
		self.device = device[self.deviceType]
	end

	if not self.device.setTextScale then
		self.device.setTextScale = function() end
	end

	self.device.setTextScale(self.textScale)
	self.width, self.height = self.device.getSize()

	self.isColor = self.device.isColor()

	self.canvas = Canvas({
		x = 1, y = 1, width = self.width, height = self.height,
		isColor = self.isColor,
	})
	self.canvas:clear(self.backgroundColor, self.textColor)
end

function UI.Device:resize()
	self.device.setTextScale(self.textScale)
	self.width, self.height = self.device.getSize()
	self.lines = { }
	self.canvas:resize(self.width, self.height)
	self.canvas:clear(self.backgroundColor, self.textColor)
end

function UI.Device:setCursorPos(x, y)
	self.cursorX = x
	self.cursorY = y
end

function UI.Device:getCursorBlink()
	return self.cursorBlink
end

function UI.Device:setCursorBlink(blink)
	self.cursorBlink = blink
	self.device.setCursorBlink(blink)
end

function UI.Device:setTextScale(textScale)
	self.textScale = textScale
	self.device.setTextScale(self.textScale)
end

function UI.Device:reset()
	self.device.setBackgroundColor(colors.black)
	self.device.setTextColor(colors.white)
	self.device.clear()
	self.device.setCursorPos(1, 1)
end

function UI.Device:addTransition(effect, args)
	if not self.transitions then
		self.transitions = { }
	end

	args = args or { }
	args.ex = args.x + args.width - 1
	args.ey = args.y + args.height - 1
	args.canvas = args.canvas or self.canvas

	if type(effect) == 'string' then
		effect = Transition[effect]
		if not effect then
			error('Invalid transition')
		end
	end

	table.insert(self.transitions, { update = effect(args), args = args })
end

function UI.Device:runTransitions(transitions, canvas)
	for _,t in ipairs(transitions) do
		canvas:punch(t.args)               -- punch out the effect areas
	end
	canvas:blitClipped(self.device) -- and blit the remainder
	canvas:reset()

	while true do
		for _,k in ipairs(Util.keys(transitions)) do
			local transition = transitions[k]
			if not transition.update(self.device) then
				transitions[k] = nil
			end
		end
		if Util.empty(transitions) then
			break
		end
		os.sleep(0)
	end
end

function UI.Device:sync()
	local transitions
	if self.transitions and self.effectsEnabled then
		transitions = self.transitions
		self.transitions = nil
	end

	if self:getCursorBlink() then
		self.device.setCursorBlink(false)
	end

	if transitions then
		self:runTransitions(transitions, self.canvas)
	else
		self.canvas:render(self.device)
	end

	if self:getCursorBlink() then
		self.device.setCursorPos(self.cursorX, self.cursorY)
		self.device.setCursorBlink(true)
	end
end

--[[-- StringBuffer --]]--
-- justs optimizes string concatenations
UI.StringBuffer = class()
function UI.StringBuffer:init(bufSize)
	self.bufSize = bufSize
	self.buffer = {}
end

function UI.StringBuffer:insert(s, width)
	local len = #tostring(s or '')
	if len > width then
		s = _sub(s, 1, width)
	end
	table.insert(self.buffer, s)
	if len < width then
		table.insert(self.buffer, _rep(' ', width - len))
	end
end

function UI.StringBuffer:insertRight(s, width)
	local len = #tostring(s or '')
	if len > width then
		s = _sub(s, 1, width)
	end
	if len < width then
		table.insert(self.buffer, _rep(' ', width - len))
	end
	table.insert(self.buffer, s)
end

function UI.StringBuffer:get(sep)
	return Util.widthify(table.concat(self.buffer, sep or ''), self.bufSize)
end

function UI.StringBuffer:clear()
	self.buffer = { }
end

-- For manipulating text in a fixed width string
local SB = { }
function SB:new(width)
	return setmetatable({
		width = width,
		buf = _rep(' ', width)
	}, { __index = SB })
end
function SB:insert(x, str, width)
	if x < 1 then
		x = self.width + x + 1
	end
	width = width or #str
	if x + width - 1 > self.width then
		width = self.width - x
	end
	if width > 0 then
		self.buf = _sub(self.buf, 1, x - 1) .. _sub(str, 1, width) .. _sub(self.buf, x + width)
	end
end
function SB:fill(x, ch, width)
	width = width or self.width - x + 1
	self:insert(x, _rep(ch, width))
end
function SB:center(str)
	self:insert(math.max(1, math.ceil((self.width - #str + 1) / 2)), str)
end
function SB:get()
	return self.buf
end

--[[-- Page (focus manager) --]]--
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
end

function UI.Page:setParent()
	UI.Window.setParent(self)
	if self.z then
		self.canvas = self:addLayer(self.backgroundColor, self.textColor)
		self.canvas:clear(self.backgroundColor, self.textColor)
	else
		self.canvas = self.parent.canvas
	end
end

function UI.Page:enable()
	self.canvas.visible = true
	UI.Window.enable(self)

	if not self.focused or not self.focused.enabled then
		self:focusFirst()
	end
end

function UI.Page:disable()
	if self.z then
		self.canvas.visible = false
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
		self.focused:emit({ type = 'focus_lost', focused = child })
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

--[[-- Grid --]]--
UI.Grid = class(UI.Window)
UI.Grid.defaults = {
	UIElement = 'Grid',
	index = 1,
	inverseSort = false,
	disableHeader = false,
	marginRight = 0,
	textColor = colors.white,
	textSelectedColor = colors.white,
	backgroundColor = colors.black,
	backgroundSelectedColor = colors.gray,
	headerBackgroundColor = colors.cyan,
	headerTextColor = colors.white,
	headerSortColor = colors.yellow,
	unfocusedTextSelectedColor = colors.white,
	unfocusedBackgroundSelectedColor = colors.gray,
	focusIndicator = '>',
	sortIndicator = ' ',
	inverseSortIndicator = '^',
	values = { },
	columns = { },
	accelerators = {
		enter           = 'key_enter',
		[ 'control-c' ] = 'copy',
		down            = 'scroll_down',
		up              = 'scroll_up',
		home            = 'scroll_top',
		[ 'end' ]       = 'scroll_bottom',
		pageUp          = 'scroll_pageUp',
		[ 'control-b' ] = 'scroll_pageUp',
		pageDown        = 'scroll_pageDown',
		[ 'control-f' ] = 'scroll_pageDown',
	},
}
function UI.Grid:setParent()
	UI.Window.setParent(self)

	for _,c in pairs(self.columns) do
		c.cw = c.width
		if not c.heading then
			c.heading = ''
		end
	end

	self:update()

	if not self.pageSize then
		if self.disableHeader then
			self.pageSize = self.height
		else
			self.pageSize = self.height - 1
		end
	end
end

function UI.Grid:resize()
	UI.Window.resize(self)

	if self.disableHeader then
		self.pageSize = self.height
	else
		self.pageSize = self.height - 1
	end
	self:adjustWidth()
end

function UI.Grid:adjustWidth()
	local t = { }        -- cols without width
	local w = self.width - #self.columns - 1 - self.marginRight -- width remaining

	for _,c in pairs(self.columns) do
		if c.width then
			c.cw = c.width
			w = w - c.cw
		else
			table.insert(t, c)
		end
	end

	if #t == 0 then
		return
	end

	if #t == 1 then
		t[1].cw = #(t[1].heading or '')
		t[1].cw = math.max(t[1].cw, w)
		return
	end

	if not self.autospace then
		for k,c in ipairs(t) do
			c.cw = math.floor(w / (#t - k + 1))
			w = w - c.cw
		end

	else
		for _,c in ipairs(t) do
			c.cw = #(c.heading or '')
			w = w - c.cw
		end
		-- adjust the size to the length of the value
		for key,row in pairs(self.values) do
			if w <= 0 then
				break
			end
			row = self:getDisplayValues(row, key)
			for _,col in pairs(t) do
				local value = row[col.key]
				if value then
					value = tostring(value)
					if #value > col.cw then
						w = w + col.cw
						col.cw = math.min(#value, w)
						w = w - col.cw
						if w <= 0 then
							break
						end
					end
				end
			end
		end

		-- last column does not get padding (right alignment)
		if not self.columns[#self.columns].width then
			Util.removeByValue(t, self.columns[#self.columns])
		end

		-- got some extra room - add some padding
		if w > 0 then
			for k,c in ipairs(t) do
				local padding = math.floor(w / (#t - k + 1))
				c.cw = c.cw + padding
				w = w - padding
			end
		end
	end
end

function UI.Grid:setPageSize(pageSize)
	self.pageSize = pageSize
end

function UI.Grid:getValues()
	return self.values
end

function UI.Grid:setValues(t)
	self.values = t
	self:update()
end

function UI.Grid:setInverseSort(inverseSort)
	self.inverseSort = inverseSort
	self:update()
	self:setIndex(self.index)
end

function UI.Grid:setSortColumn(column)
	self.sortColumn = column
end

function UI.Grid:getDisplayValues(row, key)
	return row
end

function UI.Grid:getSelected()
	if self.sorted then
		return self.values[self.sorted[self.index]], self.sorted[self.index]
	end
end

function UI.Grid:setSelected(name, value)
	if self.sorted then
		for k,v in pairs(self.sorted) do
			if self.values[v][name] == value then
				self:setIndex(k)
				return
			end
		end
	end
	self:setIndex(1)
end

function UI.Grid:focus()
	self:drawRows()
end

function UI.Grid:draw()
	if not self.disableHeader then
		self:drawHeadings()
	end

	if self.index <= 0 then
		self:setIndex(1)
	elseif self.index > #self.sorted then
		self:setIndex(#self.sorted)
	end
	self:drawRows()
end

-- Something about the displayed table has changed
-- resort the table
function UI.Grid:update()
	local function sort(a, b)
		if not a[self.sortColumn] then
			return false
		elseif not b[self.sortColumn] then
			return true
		end
		return self:sortCompare(a, b)
	end

	local function inverseSort(a, b)
		return not sort(a, b)
	end

	local order
	if self.sortColumn then
		order = sort
		if self.inverseSort then
			order = inverseSort
		end
	end

	self.sorted = Util.keys(self.values)
	if order then
		table.sort(self.sorted, function(a,b)
			return order(self.values[a], self.values[b])
		end)
	end

	self:adjustWidth()
end

function UI.Grid:drawHeadings()
	local x = 1
	for _,col in ipairs(self.columns) do
		local ind = ' '
		if col.key == self.sortColumn then
			if self.inverseSort then
				ind = self.inverseSortIndicator
			else
				ind = self.sortIndicator
			end
		end
		self:write(x,
			1,
			Util.widthify(ind .. col.heading, col.cw + 1),
			self.headerBackgroundColor,
			col.key == self.sortColumn and self.headerSortColor or self.headerTextColor)
		x = x + col.cw + 1
	end
end

function UI.Grid:sortCompare(a, b)
	a = safeValue(a[self.sortColumn])
	b = safeValue(b[self.sortColumn])
	if type(a) == type(b) then
		return a < b
	end
	return tostring(a) < tostring(b)
end

function UI.Grid:drawRows()
	local y = 1
	local startRow = math.max(1, self:getStartRow())
	local sb = UI.StringBuffer(self.width)

	if not self.disableHeader then
		y = y + 1
	end

	local lastRow = math.min(startRow + self.pageSize - 1, #self.sorted)
	for index = startRow, lastRow do

		local sindex = self.sorted[index]
		local rawRow = self.values[sindex]
		local key = sindex
		local row = self:getDisplayValues(rawRow, key)

		sb:clear()

		local ind = ' '
		if self.focused and index == self.index and not self.inactive then
			ind = self.focusIndicator
		end

		for _,col in pairs(self.columns) do
			if col.justify == 'right' then
				sb:insertRight(ind .. safeValue(row[col.key] or ''), col.cw + 1)
			else
				sb:insert(ind .. safeValue(row[col.key] or ''), col.cw + 1)
			end
			ind = ' '
		end

		local selected = index == self.index and not self.inactive

		self:write(1, y, sb:get(),
			self:getRowBackgroundColor(rawRow, selected),
			self:getRowTextColor(rawRow, selected))

		y = y + 1
	end

	if y <= self.height then
		self:clearArea(1, y, self.width, self.height - y + 1)
	end
end

function UI.Grid:getRowTextColor(row, selected)
	if selected then
		if self.focused then
			return self.textSelectedColor
		end
		return self.unfocusedTextSelectedColor
	end
	return self.textColor
end

function UI.Grid:getRowBackgroundColor(row, selected)
	if selected then
		if self.focused then
			return self.backgroundSelectedColor
		end
		return self.unfocusedBackgroundSelectedColor
	end
	return self.backgroundColor
end

function UI.Grid:getIndex()
	return self.index
end

function UI.Grid:setIndex(index)
	index = math.max(1, index)
	self.index = math.min(index, #self.sorted)

	local selected = self:getSelected()
	if selected ~= self.selected then
		self:drawRows()
		self.selected = selected
		if selected then
			self:emit({ type = 'grid_focus_row', selected = selected, element = self })
		end
	end
end

function UI.Grid:getStartRow()
	return math.floor((self.index - 1) / self.pageSize) * self.pageSize + 1
end

function UI.Grid:getPage()
	return math.floor(self.index / self.pageSize) + 1
end

function UI.Grid:getPageCount()
	local tableSize = Util.size(self.values)
	local pc = math.floor(tableSize / self.pageSize)
	if tableSize % self.pageSize > 0 then
		pc = pc + 1
	end
	return pc
end

function UI.Grid:nextPage()
	self:setPage(self:getPage() + 1)
end

function UI.Grid:previousPage()
	self:setPage(self:getPage() - 1)
end

function UI.Grid:setPage(pageNo)
	-- 1 based paging
	self:setIndex((pageNo-1) * self.pageSize + 1)
end

function UI.Grid:eventHandler(event)
	if event.type == 'mouse_click' or
		 event.type == 'mouse_rightclick' or
		 event.type == 'mouse_doubleclick' then
		if not self.disableHeader then
			if event.y == 1 then
				local col = 2
				for _,c in ipairs(self.columns) do
					if event.x < col + c.cw then
						self:emit({
							type = 'grid_sort',
							sortColumn = c.key,
							inverseSort = self.sortColumn == c.key and not self.inverseSort,
							element = self,
						})
						break
					end
					col = col + c.cw + 1
				end
				return true
			end
		end
		local row = self:getStartRow() + event.y - 1
		if not self.disableHeader then
			row = row - 1
		end
		if row > 0 and row <= Util.size(self.values) then
			self:setIndex(row)
			if event.type == 'mouse_doubleclick' then
				self:emit({ type = 'key_enter' })
			elseif event.type == 'mouse_rightclick' then
				self:emit({ type = 'grid_select_right', selected = self.selected, element = self })
			end
			return true
		end
		return false

	elseif event.type == 'grid_sort' then
		self.sortColumn = event.sortColumn
		self:setInverseSort(event.inverseSort)
		self:draw()
	elseif event.type == 'scroll_down' then
		self:setIndex(self.index + 1)
	elseif event.type == 'scroll_up' then
		self:setIndex(self.index - 1)
	elseif event.type == 'scroll_top' then
		self:setIndex(1)
	elseif event.type == 'scroll_bottom' then
		self:setIndex(Util.size(self.values))
	elseif event.type == 'scroll_pageUp' then
		self:setIndex(self.index - self.pageSize)
	elseif event.type == 'scroll_pageDown' then
		self:setIndex(self.index + self.pageSize)
	elseif event.type == 'key_enter' then
		if self.selected then
			self:emit({ type = 'grid_select', selected = self.selected, element = self })
		end
	elseif event.type == 'copy' then
		if self.selected then
			os.queueEvent('clipboard_copy', self.selected)
		end
	else
		return false
	end
	return true
end

--[[-- ScrollingGrid  --]]--
UI.ScrollingGrid = class(UI.Grid)
UI.ScrollingGrid.defaults = {
	UIElement = 'ScrollingGrid',
	scrollOffset = 0,
	marginRight = 1,
}
function UI.ScrollingGrid:postInit()
	self.scrollBar = UI.ScrollBar()
end

function UI.ScrollingGrid:drawRows()
	UI.Grid.drawRows(self)
	self.scrollBar:draw()
end

function UI.ScrollingGrid:getViewArea()
	local y = 1
	if not self.disableHeader then
		y = 2
	end
	return {
		static      = true,                    -- the container doesn't scroll
		y           = y,                       -- scrollbar Y
		height      = self.pageSize,           -- viewable height
		totalHeight = Util.size(self.values),  -- total height
		offsetY     = self.scrollOffset,       -- scroll offset
	}
end

function UI.ScrollingGrid:getStartRow()
	local ts = Util.size(self.values)
	if ts < self.pageSize then
		self.scrollOffset = 0
	end
	return self.scrollOffset + 1
end

function UI.ScrollingGrid:setIndex(index)
	if index < self.scrollOffset + 1 then
		self.scrollOffset = index - 1
	elseif index - self.scrollOffset > self.pageSize then
		self.scrollOffset = index - self.pageSize
	end

	if self.scrollOffset < 0 then
		self.scrollOffset = 0
	else
		local ts = Util.size(self.values)
		if self.pageSize + self.scrollOffset + 1 > ts then
			self.scrollOffset = math.max(0, ts - self.pageSize)
		end
	end
	UI.Grid.setIndex(self, index)
end

--[[-- Menu --]]--
UI.Menu = class(UI.Grid)
UI.Menu.defaults = {
	UIElement = 'Menu',
	disableHeader = true,
	columns = { { heading = 'Prompt', key = 'prompt', width = 20 } },
}
function UI.Menu:postInit()
	self.values = self.menuItems
	self.pageSize = #self.menuItems
end

function UI.Menu:setParent()
	UI.Grid.setParent(self)
	self.itemWidth = 1
	for _,v in pairs(self.values) do
		if #v.prompt > self.itemWidth then
			self.itemWidth = #v.prompt
		end
	end
	self.columns[1].width = self.itemWidth

	if self.centered then
		self:center()
	else
		self.width = self.itemWidth + 2
	end
end

function UI.Menu:center()
	self.x = (self.width - self.itemWidth + 2) / 2
	self.width = self.itemWidth + 2
end

function UI.Menu:eventHandler(event)
	if event.type == 'key' then
		if event.key == 'enter' then
			local selected = self.menuItems[self.index]
			self:emit({
				type = selected.event or 'menu_select',
				selected = selected
			})
			return true
		end
	elseif event.type == 'mouse_click' then
		if event.y <= #self.menuItems then
			UI.Grid.setIndex(self, event.y)
			local selected = self.menuItems[self.index]
			self:emit({
				type = selected.event or 'menu_select',
				selected = selected
			})
			return true
		end
	end
	return UI.Grid.eventHandler(self, event)
end

--[[-- Viewport --]]--
UI.Viewport = class(UI.Window)
UI.Viewport.defaults = {
	UIElement = 'Viewport',
	backgroundColor = colors.cyan,
	accelerators = {
		down            = 'scroll_down',
		up              = 'scroll_up',
		home            = 'scroll_top',
		[ 'end' ]       = 'scroll_bottom',
		pageUp          = 'scroll_pageUp',
		[ 'control-b' ] = 'scroll_pageUp',
		pageDown        = 'scroll_pageDown',
		[ 'control-f' ] = 'scroll_pageDown',
	},
}
function UI.Viewport:setScrollPosition(offset)
	local oldOffset = self.offy
	self.offy = math.max(offset, 0)
	local max = self.ymax or self.height
	if self.children then
		for _, child in ipairs(self.children) do
			if child ~= self.scrollBar then                         -- hack !
				max = math.max(child.y + child.height - 1, max)
			end
		end
	end
	self.offy = math.min(self.offy, math.max(max, self.height) - self.height)
	if self.offy ~= oldOffset then
		self:draw()
	end
end

function UI.Viewport:reset()
	self.offy = 0
end

function UI.Viewport:getViewArea()
	return {
		y           = (self.offy or 0) + 1,
		height      = self.height,
		totalHeight = self.ymax,
		offsetY     = self.offy or 0,
	}
end

function UI.Viewport:eventHandler(event)
	if event.type == 'scroll_down' then
		self:setScrollPosition(self.offy + 1)
	elseif event.type == 'scroll_up' then
		self:setScrollPosition(self.offy - 1)
	elseif event.type == 'scroll_top' then
		self:setScrollPosition(0)
	elseif event.type == 'scroll_bottom' then
		self:setScrollPosition(10000000)
	elseif event.type == 'scroll_pageUp' then
		self:setScrollPosition(self.offy - self.height)
	elseif event.type == 'scroll_pageDown' then
		self:setScrollPosition(self.offy + self.height)
	else
		return false
	end
	return true
end

--[[-- TitleBar --]]--
UI.TitleBar = class(UI.Window)
UI.TitleBar.defaults = {
	UIElement = 'TitleBar',
	height = 1,
	textColor = colors.white,
	backgroundColor = colors.cyan,
	title = '',
	frameChar = '-',
	closeInd = '*',
}
function UI.TitleBar:draw()
	local sb = SB:new(self.width)
	sb:fill(2, self.frameChar, sb.width - 3)
	sb:center(string.format(' %s ', self.title))
	if self.previousPage or self.event then
		sb:insert(-1, self.closeInd)
	else
		sb:insert(-2, self.frameChar)
	end
	self:write(1, 1, sb:get())
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
	end
end

--[[-- Button --]]--
UI.Button = class(UI.Window)
UI.Button.defaults = {
	UIElement = 'Button',
	text = 'button',
	backgroundColor = colors.lightGray,
	backgroundFocusColor = colors.gray,
	textFocusColor = colors.white,
	textInactiveColor = colors.gray,
	textColor = colors.black,
	centered = true,
	height = 1,
	focusIndicator = ' ',
	event = 'button_press',
	accelerators = {
		space = 'button_activate',
		enter = 'button_activate',
		mouse_click = 'button_activate',
	}
}
function UI.Button:setParent()
	if not self.width and not self.ex then
		self.width = #self.text + 2
	end
	UI.Window.setParent(self)
end

function UI.Button:draw()
	local fg = self.textColor
	local bg = self.backgroundColor
	local ind = ' '
	if self.focused then
		bg = self.backgroundFocusColor
		fg = self.textFocusColor
		ind = self.focusIndicator
	elseif self.inactive then
		fg = self.textInactiveColor
	end
	local text = ind .. self.text .. ' '
	if self.centered then
		self:clear(bg)
		self:centeredWrite(1 + math.floor(self.height / 2), text, bg, fg)
	else
		self:write(1, 1, Util.widthify(text, self.width), bg, fg)
	end
end

function UI.Button:focus()
	if self.focused then
		self:scrollIntoView()
	end
	self:draw()
end

function UI.Button:eventHandler(event)
	if event.type == 'button_activate' then
		self:emit({ type = self.event, button = self })
		return true
	end
	return false
end

--[[-- MenuItem --]]--
UI.MenuItem = class(UI.Button)
UI.MenuItem.defaults = {
	UIElement = 'MenuItem',
	textColor = colors.black,
	backgroundColor = colors.lightGray,
	textFocusColor = colors.white,
	backgroundFocusColor = colors.lightGray,
}

--[[-- MenuBar --]]--
UI.MenuBar = class(UI.Window)
UI.MenuBar.defaults = {
	UIElement = 'MenuBar',
	buttons = { },
	height = 1,
	backgroundColor = colors.lightGray,
	textColor = colors.black,
	spacing = 2,
	lastx = 1,
	showBackButton = false,
	buttonClass = 'MenuItem',
}
UI.MenuBar.spacer = { spacer = true, text = 'spacer', inactive = true }

function UI.MenuBar:postInit()
	self:addButtons(self.buttons)
end

function UI.MenuBar:addButtons(buttons)
	if not self.children then
		self.children = { }
	end

	for _,button in pairs(buttons) do
		if button.UIElement then
			table.insert(self.children, button)
		else
			local buttonProperties = {
				x = self.lastx,
				width = #button.text + self.spacing,
				centered = false,
			}
			self.lastx = self.lastx + buttonProperties.width
			UI:mergeProperties(buttonProperties, button)

			button = UI[self.buttonClass](buttonProperties)
			if button.name then
				self[button.name] = button
			else
				table.insert(self.children, button)
			end

			if button.dropdown then
				button.dropmenu = UI.DropMenu { buttons = button.dropdown }
			end
		end
	end
	if self.parent then
		self:initChildren()
	end
end

function UI.MenuBar:getActive(menuItem)
	return not menuItem.inactive
end

function UI.MenuBar:eventHandler(event)
	if event.type == 'button_press' and event.button.dropmenu then
		if event.button.dropmenu.enabled then
			event.button.dropmenu:hide()
			return true
		else
			local x, y = getPosition(event.button)
			if x + event.button.dropmenu.width > self.width then
				x = self.width - event.button.dropmenu.width + 1
			end
			for _,c in pairs(event.button.dropmenu.children) do
				if not c.spacer then
					c.inactive = not self:getActive(c)
				end
			end
			event.button.dropmenu:show(x, y + 1)
		end
		return true
	end
end

--[[-- DropMenuItem --]]--
UI.DropMenuItem = class(UI.Button)
UI.DropMenuItem.defaults = {
	UIElement = 'DropMenuItem',
	textColor = colors.black,
	backgroundColor = colors.white,
	textFocusColor = colors.white,
	textInactiveColor = colors.lightGray,
	backgroundFocusColor = colors.lightGray,
}
function UI.DropMenuItem:eventHandler(event)
	if event.type == 'button_activate' then
		self.parent:hide()
	end
	return UI.Button.eventHandler(self, event)
end

--[[-- DropMenu --]]--
UI.DropMenu = class(UI.MenuBar)
UI.DropMenu.defaults = {
	UIElement = 'DropMenu',
	backgroundColor = colors.white,
	buttonClass = 'DropMenuItem',
}
function UI.DropMenu:setParent()
	UI.MenuBar.setParent(self)

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
			child.text = string.rep('-', child.width - 2)
		end
	end

	self.height = #self.children + 1
	self.width = maxWidth + 2
	self.ow = self.width

	self.canvas = self:addLayer()
end

function UI.DropMenu:enable()
	self.enabled = false
end

function UI.DropMenu:show(x, y)
	self.x, self.y = x, y
	self.canvas:move(x, y)
	self.canvas:setVisible(true)

	self.enabled = true
	for _,child in pairs(self.children) do
		child:enable()
	end

	self:draw()
	self:capture(self)
	self:focusFirst()
end

function UI.DropMenu:hide()
	self:disable()
	self.canvas:setVisible(false)
	self:release(self)
end

function UI.DropMenu:eventHandler(event)
	if event.type == 'focus_lost' and self.enabled then
		if not Util.contains(self.children, event.focused) then
			self:hide()
		end
	elseif event.type == 'mouse_out' and self.enabled then
		self:hide()
		self:refocus()
	else
		return UI.MenuBar.eventHandler(self, event)
	end
	return true
end

--[[-- TabBarMenuItem --]]--
UI.TabBarMenuItem = class(UI.Button)
UI.TabBarMenuItem.defaults = {
	UIElement = 'TabBarMenuItem',
	event = 'tab_select',
	textColor = colors.black,
	selectedBackgroundColor = colors.cyan,
	unselectedBackgroundColor = colors.lightGray,
	backgroundColor = colors.lightGray,
}
function UI.TabBarMenuItem:draw()
	if self.selected then
		self.backgroundColor = self.selectedBackgroundColor
		self.backgroundFocusColor = self.selectedBackgroundColor
	else
		self.backgroundColor = self.unselectedBackgroundColor
		self.backgroundFocusColor = self.unselectedBackgroundColor
	end
	UI.Button.draw(self)
end

--[[-- TabBar --]]--
UI.TabBar = class(UI.MenuBar)
UI.TabBar.defaults = {
	UIElement = 'TabBar',
	buttonClass = 'TabBarMenuItem',
	selectedBackgroundColor = colors.cyan,
}
function UI.TabBar:enable()
	UI.MenuBar.enable(self)
	if not Util.find(self.children, 'selected', true) then
		local menuItem = self:getFocusables()[1]
		if menuItem then
			menuItem.selected = true
		end
	end
end

function UI.TabBar:eventHandler(event)
	if event.type == 'tab_select' then
		local selected, si = Util.find(self:getFocusables(), 'uid', event.button.uid)
		local previous, pi = Util.find(self:getFocusables(), 'selected', true)

		if si ~= pi then
			selected.selected = true
			previous.selected = false
			self:emit({ type = 'tab_change', current = si, last = pi, tab = selected })
		end
		UI.MenuBar.draw(self)
	end
	return UI.MenuBar.eventHandler(self, event)
end

function UI.TabBar:selectTab(text)
	local menuItem = Util.find(self.children, 'text', text)
	if menuItem then
		menuItem.selected = true
	end
end

--[[-- Tabs --]]--
UI.Tabs = class(UI.Window)
UI.Tabs.defaults = {
	UIElement = 'Tabs',
}
function UI.Tabs:postInit()
	self:add(self)
end

function UI.Tabs:add(children)
	local buttons = { }
	for _,child in pairs(children) do
		if type(child) == 'table' and child.UIElement and child.tabTitle then
			child.y = 2
			table.insert(buttons, {
				text = child.tabTitle,
				event = 'tab_select',
				tabUid = child.uid,
			})
		end
	end

	if not self.tabBar then
		self.tabBar = UI.TabBar({
			buttons = buttons,
		})
	else
		self.tabBar:addButtons(buttons)
	end

	if self.parent then
		return UI.Window.add(self, children)
	end
end

function UI.Tabs:enable()
	self.enabled = true
	self.tabBar:enable()

	local menuItem = Util.find(self.tabBar.children, 'selected', true)

	for _,child in pairs(self.children) do
		if child.uid == menuItem.tabUid then
			child:enable()
			self:emit({ type = 'tab_activate', activated = child })
		elseif child.tabTitle then
			child:disable()
		end
	end
end

function UI.Tabs:eventHandler(event)
	if event.type == 'tab_change' then
		local tab = self:find(event.tab.tabUid)
		if event.current > event.last then
			tab:addTransition('slideLeft')
		else
			tab:addTransition('slideRight')
		end

		for _,child in pairs(self.children) do
			if child.uid == event.tab.tabUid then
				child:enable()
			elseif child.tabTitle then
				child:disable()
			end
		end
		self:emit({ type = 'tab_activate', activated = tab })
		tab:draw()
	end
end

--[[-- Wizard --]]--
UI.Wizard = class(UI.Window)
UI.Wizard.defaults = {
	UIElement = 'Wizard',
	pages = { },
}
function UI.Wizard:postInit()
	self.cancelButton = UI.Button {
		x = 2, y = -1,
		text = 'Cancel',
		event = 'cancel',
	}
	self.previousButton = UI.Button {
		x = -18, y = -1,
		text = '< Back',
		event = 'previousView',
	}
	self.nextButton = UI.Button {
		x = -9, y = -1,
		text = 'Next >',
		event = 'nextView',
	}

	Util.merge(self, self.pages)
	for _, child in pairs(self.pages) do
		child.ey = -2
	end
end

function UI.Wizard:add(pages)
	Util.merge(self.pages, pages)
	Util.merge(self, pages)

	for _, child in pairs(self.pages) do
		child.ey = child.ey or -2
	end

	if self.parent then
		self:initChildren()
	end
end

function UI.Wizard:getPage(index)
	return Util.find(self.pages, 'index', index)
end

function UI.Wizard:enable(...)
	self.enabled = true
	self.index = 1
	local initial = self:getPage(1)
	for _,child in pairs(self.children) do
		if child == initial or not child.index then
			child:enable(...)
		else
			child:disable()
		end
	end
	self:emit({ type = 'enable_view', next = initial })
end

function UI.Wizard:isViewValid()
	local currentView = self:getPage(self.index)
	return not currentView.validate and true or currentView:validate()
end

function UI.Wizard:eventHandler(event)
	if event.type == 'nextView' then
		local currentView = self:getPage(self.index)
		if self:isViewValid() then
			self.index = self.index + 1
			local nextView = self:getPage(self.index)
			currentView:emit({ type = 'enable_view', next = nextView, current = currentView })
		end

	elseif event.type == 'previousView' then
		local currentView = self:getPage(self.index)
		local nextView = self:getPage(self.index - 1)
		if nextView then
			self.index = self.index - 1
			currentView:emit({ type = 'enable_view', prev = nextView, current = currentView })
		end
		return true

	elseif event.type == 'wizard_complete' then
		if self:isViewValid() then
			self:emit({ type = 'accept' })
		end

	elseif event.type == 'enable_view' then
		if event.current then
			if event.next then
				self:addTransition('slideLeft')
			elseif event.prev then
				self:addTransition('slideRight')
			end
			event.current:disable()
		end

		local current = event.next or event.prev
		if not current then error('property "index" is required on wizard pages') end

		if self:getPage(self.index - 1) then
			self.previousButton:enable()
		else
			self.previousButton:disable()
		end

		if self:getPage(self.index + 1) then
			self.nextButton.text = 'Next >'
			self.nextButton.event = 'nextView'
		else
			self.nextButton.text = 'Accept'
			self.nextButton.event = 'wizard_complete'
		end
		-- a new current view
		current:enable()
		self:draw()
	end
end

--[[-- SlideOut --]]--
UI.SlideOut = class(UI.Window)
UI.SlideOut.defaults = {
	UIElement = 'SlideOut',
	pageType = 'modal',
}
function UI.SlideOut:setParent()
	UI.Window.setParent(self)
	self.canvas = self:addLayer()
end

function UI.SlideOut:enable()
	self.enabled = false
end

function UI.SlideOut:show(...)
	self:addTransition('expandUp')
	self.canvas:setVisible(true)
	self.enabled = true
	for _,child in pairs(self.children) do
		child:enable(...)
	end
	self:draw()
	self:capture(self)
	self:focusFirst()
end

function UI.SlideOut:disable()
	self.canvas:setVisible(false)
	self.enabled = false
	if self.children then
		for _,child in pairs(self.children) do
			child:disable()
		end
	end
end

function UI.SlideOut:hide()
	self:disable()
	self:release(self)
	self:refocus()
end

function UI.SlideOut:eventHandler(event)
	if event.type == 'slide_show' then
		self:show()
		return true

	elseif event.type == 'slide_hide' then
		self:hide()
		return true
	end
end

--[[-- Embedded --]]--
UI.Embedded = class(UI.Window)
UI.Embedded.defaults = {
	UIElement = 'Embedded',
	backgroundColor = colors.black,
	textColor = colors.white,
	accelerators = {
		up = 'scroll_up',
		down = 'scroll_down',
	}
}

function UI.Embedded:setParent()
	UI.Window.setParent(self)
	self.win = window.create(UI.term.device, 1, 1, self.width, self.height, false)
	Canvas.scrollingWindow(self.win, self.x, self.y)
	self.win.setParent(UI.term.device)
	self.win.setMaxScroll(100)

	local canvas = self:getCanvas()
	self.win.canvas.parent = canvas
	table.insert(canvas.layers, self.win.canvas)
	self.canvas = self.win.canvas

	self.win.setCursorPos(1, 1)
	self.win.setBackgroundColor(self.backgroundColor)
	self.win.setTextColor(self.textColor)
	self.win.clear()
end

function UI.Embedded:draw()
	self.canvas:dirty()
end

function UI.Embedded:enable()
	self.canvas:setVisible(true)
	UI.Window.enable(self)
end

function UI.Embedded:disable()
	self.canvas:setVisible(false)
	UI.Window.disable(self)
end

function UI.Embedded:eventHandler(event)
	if event.type == 'scroll_up' then
		self.win.scrollUp()
		return true
	elseif event.type == 'scroll_down' then
		self.win.scrollDown()
		return true
	end
end

function UI.Embedded:focus()
	-- allow scrolling
end

--[[-- Notification --]]--
UI.Notification = class(UI.Window)
UI.Notification.defaults = {
	UIElement = 'Notification',
	backgroundColor = colors.gray,
	height = 3,
}
function UI.Notification:draw()
end

function UI.Notification:enable()
	self.enabled = false
end

function UI.Notification:error(value, timeout)
	self.backgroundColor = colors.red
	Sound.play('entity.villager.no', .5)
	self:display(value, timeout)
end

function UI.Notification:info(value, timeout)
	self.backgroundColor = colors.gray
	self:display(value, timeout)
end

function UI.Notification:success(value, timeout)
	self.backgroundColor = colors.green
	self:display(value, timeout)
end

function UI.Notification:cancel()
	if self.canvas then
		Event.cancelNamedTimer('notificationTimer')
		self.enabled = false
		self.canvas:removeLayer()
		self.canvas = nil
	end
end

function UI.Notification:display(value, timeout)
	self.enabled = true
	local lines = Util.wordWrap(value, self.width - 2)
	self.height = #lines + 1
	self.y = self.parent.height - self.height + 1
	if self.canvas then
		self.canvas:removeLayer()
	end

	self.canvas = self:addLayer(self.backgroundColor, self.textColor)
	self:addTransition('expandUp', { ticks = self.height })
	self.canvas:setVisible(true)
	self:clear()
	for k,v in pairs(lines) do
		self:write(2, k, v)
	end

	Event.addNamedTimer('notificationTimer', timeout or 3, false, function()
		self:cancel()
		self:sync()
	end)
end

--[[-- Throttle --]]--
UI.Throttle = class(UI.Window)
UI.Throttle.defaults = {
	UIElement = 'Throttle',
	backgroundColor = colors.gray,
	bordercolor = colors.cyan,
	height = 4,
	width = 10,
	timeout = .075,
	ctr = 0,
	image = {
		'  //)    (O )~@ &~&-( ?Q        ',
		'  //)    (O )- @  \\-( ?)  &&    ',
		'  //)    (O ), @  \\-(?)     &&  ',
		'  //)    (O ). @  \\-d )      (@ '
	}
}
function UI.Throttle:setParent()
	self.x = math.ceil((self.parent.width - self.width) / 2)
	self.y = math.ceil((self.parent.height - self.height) / 2)
	UI.Window.setParent(self)
end

function UI.Throttle:enable()
	self.c = os.clock()
	self.enabled = false
end

function UI.Throttle:disable()
	if self.canvas then
		self.enabled = false
		self.canvas:removeLayer()
		self.canvas = nil
		self.ctr = 0
	end
end

function UI.Throttle:update()
	local cc = os.clock()
	if cc > self.c + self.timeout then
		os.sleep(0)
		self.c = os.clock()
		self.enabled = true
		if not self.canvas then
			self.canvas = self:addLayer(self.backgroundColor, self.borderColor)
			self.canvas:setVisible(true)
			self:clear(self.borderColor)
		end
		local image = self.image[self.ctr + 1]
		local width = self.width - 2
		for i = 0, #self.image do
			self:write(2, i + 1, image:sub(width * i + 1, width * i + width),
				self.backgroundColor, self.textColor)
		end

		self.ctr = (self.ctr + 1) % #self.image

		self:sync()
	end
end

--[[-- StatusBar --]]--
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
	timeout = timeout or 3
	self:write(2, 1, Util.widthify(status, self.width-2), self.backgroundColor)
	Event.addNamedTimer('statusTimer', timeout, false, function()
		if self.parent.enabled then
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

--[[-- ProgressBar --]]--
UI.ProgressBar = class(UI.Window)
UI.ProgressBar.defaults = {
	UIElement = 'ProgressBar',
	progressColor = colors.lime,
	backgroundColor = colors.gray,
	height = 1,
	value = 0,
}
function UI.ProgressBar:draw()
	self:clear()
	local width = math.ceil(self.value / 100 * self.width)
	self:clearArea(1, 1, width, self.height, self.progressColor)
end

--[[-- VerticalMeter --]]--
UI.VerticalMeter = class(UI.Window)
UI.VerticalMeter.defaults = {
	UIElement = 'VerticalMeter',
	backgroundColor = colors.gray,
	meterColor = colors.lime,
	width = 1,
	value = 0,
}
function UI.VerticalMeter:draw()
	local height = self.height - math.ceil(self.value / 100 * self.height)
	self:clear()
	self:clearArea(1, height + 1, self.width, self.height, self.meterColor)
end

--[[-- TextEntry --]]--
UI.TextEntry = class(UI.Window)
UI.TextEntry.defaults = {
	UIElement = 'TextEntry',
	value = '',
	shadowText = '',
	focused = false,
	textColor = colors.white,
	shadowTextColor = colors.gray,
	backgroundColor = colors.black, -- colors.lightGray,
	backgroundFocusColor = colors.black, --lightGray,
	height = 1,
	limit = 6,
	pos = 0,
	accelerators = {
		[ 'control-c' ] = 'copy',
	}
}
function UI.TextEntry:postInit()
	self.value = tostring(self.value)
end

function UI.TextEntry:setValue(value)
	self.value = value
end

function UI.TextEntry:setPosition(pos)
	self.pos = pos
end

function UI.TextEntry:updateScroll()
	if not self.scroll then
		self.scroll = 0
	end

	if not self.pos then
		self.pos = #tostring(self.value)
		self.scroll = 0
	elseif self.pos > #tostring(self.value) then
		self.pos = #tostring(self.value)
		self.scroll = 0
	end

	if self.pos - self.scroll > self.width - 2 then
		self.scroll = self.pos - (self.width - 2)
	elseif self.pos < self.scroll then
		self.scroll = self.pos
	end
end

function UI.TextEntry:draw()
	local bg = self.backgroundColor
	local tc = self.textColor
	if self.focused then
		bg = self.backgroundFocusColor
	end

	self:updateScroll()
	local text = tostring(self.value)
	if #text > 0 then
		if self.scroll and self.scroll > 0 then
			text = text:sub(1 + self.scroll)
		end
		if self.mask then
			text = _rep('*', #text)
		end
	else
		tc = self.shadowTextColor
		text = self.shadowText
	end

	self:write(1, 1, ' ' .. Util.widthify(text, self.width - 2) .. ' ', bg, tc)
	if self.focused then
		self:setCursorPos(self.pos-self.scroll+2, 1)
	end
end

function UI.TextEntry:reset()
	self.pos = 0
	self.value = ''
	self:draw()
	self:updateCursor()
end

function UI.TextEntry:updateCursor()
	self:updateScroll()
	self:setCursorPos(self.pos-self.scroll+2, 1)
end

function UI.TextEntry:focus()
	self:draw()
	if self.focused then
		self:setCursorBlink(true)
	else
		self:setCursorBlink(false)
	end
end

--[[
	A few lines below from theoriginalbit
	http://www.computercraft.info/forums2/index.php?/topic/16070-read-and-limit-length-of-the-input-field/
--]]
function UI.TextEntry:eventHandler(event)
	if event.type == 'key' then
		local ch = event.key
		if ch == 'left' then
			if self.pos > 0 then
				self.pos = math.max(self.pos-1, 0)
				self:draw()
			end
		elseif ch == 'right' then
			local input = tostring(self.value)
			if self.pos < #input then
				self.pos = math.min(self.pos+1, #input)
				self:draw()
			end
		elseif ch == 'home' then
			self.pos = 0
			self:draw()
		elseif ch == 'end' then
			self.pos = #tostring(self.value)
			self:draw()
		elseif ch == 'backspace' then
			if self.pos > 0 then
				local input = tostring(self.value)
				self.value = input:sub(1, self.pos-1) .. input:sub(self.pos+1)
				self.pos = self.pos - 1
				self:draw()
				self:emit({ type = 'text_change', text = self.value, element = self })
			end
		elseif ch == 'delete' then
			local input = tostring(self.value)
			if self.pos < #input then
				self.value = input:sub(1, self.pos) .. input:sub(self.pos+2)
				self:draw()
				self:emit({ type = 'text_change', text = self.value, element = self })
			end
		elseif #ch == 1 then
			local input = tostring(self.value)
			if #input < self.limit then
				self.value = input:sub(1, self.pos) .. ch .. input:sub(self.pos+1)
				self.pos = self.pos + 1
				self:draw()
				self:emit({ type = 'text_change', text = self.value, element = self })
			end
		else
			return false
		end
		return true

	elseif event.type == 'copy' then
		os.queueEvent('clipboard_copy', self.value)

	elseif event.type == 'paste' then
		local input = tostring(self.value)
		local text = event.text
		if #input + #text > self.limit then
			text = text:sub(1, self.limit-#input)
		end
		self.value = input:sub(1, self.pos) .. text .. input:sub(self.pos+1)
		self.pos = self.pos + #text
		self:draw()
		self:updateCursor()
		self:emit({ type = 'text_change', text = self.value, element = self })
		return true

	elseif event.type == 'mouse_click' then
		if self.focused and event.x > 1 then
			self.pos = event.x + self.scroll - 2
			self:updateCursor()
			return true
		end
	elseif event.type == 'mouse_rightclick' then
		local input = tostring(self.value)
		if #input > 0 then
			self:reset()
			self:emit({ type = 'text_change', text = self.value, element = self })
		end
	end

	return false
end

--[[-- Chooser --]]--
UI.Chooser = class(UI.Window)
UI.Chooser.defaults = {
	UIElement = 'Chooser',
	choices = { },
	nochoice = 'Select',
	backgroundFocusColor = colors.lightGray,
	textInactiveColor = colors.gray,
	leftIndicator = '<',
	rightIndicator = '>',
	height = 1,
}
function UI.Chooser:setParent()
	if not self.width and not self.ex then
		self.width = 1
		for _,v in pairs(self.choices) do
			if #v.name > self.width then
				self.width = #v.name
			end
		end
		self.width = self.width + 4
	end
	UI.Window.setParent(self)
end

function UI.Chooser:draw()
	local bg = self.backgroundColor
	if self.focused then
		bg = self.backgroundFocusColor
	end
	local fg = self.inactive and self.textInactiveColor or self.textColor
	local choice = Util.find(self.choices, 'value', self.value)
	local value = self.nochoice
	if choice then
		value = choice.name
	end
	self:write(1, 1, self.leftIndicator, self.backgroundColor, colors.black)
	self:write(2, 1, ' ' .. Util.widthify(tostring(value), self.width-4) .. ' ', bg, fg)
	self:write(self.width, 1, self.rightIndicator, self.backgroundColor, colors.black)
end

function UI.Chooser:focus()
	self:draw()
end

function UI.Chooser:eventHandler(event)
	if event.type == 'key' then
		if event.key == 'right' or event.key == 'space' then
			local _,k = Util.find(self.choices, 'value', self.value)
			local choice
			if k and k < #self.choices then
				choice = self.choices[k+1]
			else
				choice = self.choices[1]
			end
			self.value = choice.value
			self:emit({ type = 'choice_change', value = self.value, element = self, choice = choice })
			self:draw()
			return true
		elseif event.key == 'left' then
			local _,k = Util.find(self.choices, 'value', self.value)
			local choice
			if k and k > 1 then
				choice = self.choices[k-1]
			else
				choice = self.choices[#self.choices]
			end
			self.value = choice.value
			self:emit({ type = 'choice_change', value = self.value, element = self, choice = choice })
			self:draw()
			return true
		end
	elseif event.type == 'mouse_click' then
		if event.x == 1 then
			self:emit({ type = 'key', key = 'left' })
			return true
		elseif event.x == self.width then
			self:emit({ type = 'key', key = 'right' })
			return true
		end
	end
end

--[[-- Chooser --]]--
UI.Checkbox = class(UI.Window)
UI.Checkbox.defaults = {
	UIElement = 'Checkbox',
	nochoice = 'Select',
	checkedIndicator = 'X',
	leftMarker = '[',
	rightMarker = ']',
	value = false,
	textColor = colors.white,
	backgroundColor = colors.black,
	backgroundFocusColor = colors.lightGray,
	height = 1,
	width = 3,
	accelerators = {
		space = 'checkbox_toggle',
		mouse_click = 'checkbox_toggle',
	}
}
function UI.Checkbox:draw()
	local bg = self.backgroundColor
	if self.focused then
		bg = self.backgroundFocusColor
	end
	if type(self.value) == 'string' then
		self.value = nil  -- TODO: fix form
	end
	local text = string.format('[%s]', not self.value and ' ' or self.checkedIndicator)
	self:write(1, 1, text, bg)
	self:write(1, 1, self.leftMarker, self.backgroundColor, self.textColor)
	self:write(2, 1, not self.value and ' ' or self.checkedIndicator, bg)
	self:write(3, 1, self.rightMarker, self.backgroundColor, self.textColor)
end

function UI.Checkbox:focus()
	self:draw()
end

function UI.Checkbox:reset()
	self.value = false
end

function UI.Checkbox:eventHandler(event)
	if event.type == 'checkbox_toggle' then
		self.value = not self.value
		self:emit({ type = 'checkbox_change', checked = self.value, element = self })
		self:draw()
		return true
	end
end

--[[-- Text --]]--
UI.Text = class(UI.Window)
UI.Text.defaults = {
	UIElement = 'Text',
	value = '',
	height = 1,
}
function UI.Text:setParent()
	if not self.width and not self.ex then
		self.width = #tostring(self.value)
	end
	UI.Window.setParent(self)
end

function UI.Text:draw()
	self:write(1, 1, Util.widthify(self.value or '', self.width), self.backgroundColor)
end

--[[-- ScrollBar --]]--
UI.ScrollBar = class(UI.Window)
UI.ScrollBar.defaults = {
	UIElement = 'ScrollBar',
	lineChar = '|',
	sliderChar = '#',
	upArrowChar = '^',
	downArrowChar = 'v',
	scrollbarColor = colors.lightGray,
	value = '',
	width = 1,
	x = -1,
	ey = -1,
}
function UI.ScrollBar:draw()
	local parent = self.parent
	local view = parent:getViewArea()

	if view.totalHeight > view.height then
		local maxScroll = view.totalHeight - view.height
		local percent = view.offsetY / maxScroll
		local sliderSize = math.max(1, Util.round(view.height / view.totalHeight * (view.height - 2)))
		local x = self.width

		local row = view.y
		if not view.static then  -- does the container scroll ?
			self.y = row           -- if so, move the scrollbar onscreen
			row = 1
		end

		for i = 1, view.height - 2 do
			self:write(x, row + i, self.lineChar, nil, self.scrollbarColor)
		end

		local y = Util.round((view.height - 2 - sliderSize) * percent)
		for i = 1, sliderSize do
			self:write(x, row + y + i, self.sliderChar, nil, self.scrollbarColor)
		end

		local color = self.scrollbarColor
		if view.offsetY > 0 then
			color = colors.white
		end
		self:write(x, row, self.upArrowChar, nil, color)

		color = self.scrollbarColor
		if view.offsetY + view.height < view.totalHeight then
			color = colors.white
		end
		self:write(x, row + view.height - 1, self.downArrowChar, nil, color)
	end
end

function UI.ScrollBar:eventHandler(event)
	if event.type == 'mouse_click' or event.type == 'mouse_doubleclick' then
		if event.x == 1 then
			local view = self.parent:getViewArea()
			if view.totalHeight > view.height then
				if event.y == view.y then
					self:emit({ type = 'scroll_up'})
				elseif event.y == self.height then
					self:emit({ type = 'scroll_down'})
					-- else
					-- ... percentage ...
				end
			end
			return true
		end
	end
end

--[[-- TextArea --]]--
UI.TextArea = class(UI.Viewport)
UI.TextArea.defaults = {
	UIElement = 'TextArea',
	marginRight = 2,
	value = '',
}
function UI.TextArea:postInit()
	self.scrollBar = UI.ScrollBar()
end

function UI.TextArea:setText(text)
	self.offy = 0
	self.ymax = nil
	self.value = text
	self:draw()
end

function UI.TextArea:focus()
	-- allow keyboard scrolling
end

function UI.TextArea:draw()
	self:clear()
--  self:setCursorPos(1, 1)
	self.cursorX, self.cursorY = 1, 1
	self:print(self.value)
	self.ymax = self.cursorY + 1

	for _,child in pairs(self.children) do
		if child.enabled then
			child:draw()
		end
	end
end

--[[-- Form --]]--
UI.Form = class(UI.Window)
UI.Form.defaults = {
	UIElement = 'Form',
	values = { },
	margin = 2,
	event = 'form_complete',
}
function UI.Form:postInit()
	self:createForm()
end

function UI.Form:reset()
	for _,child in pairs(self.children) do
		if child.reset then
			child:reset()
		end
	end
end

function UI.Form:setValues(values)
	self:reset()
	self.values = values
	for _,child in pairs(self.children) do
		if child.formKey then
			-- this should be child:setValue(self.values[child.formKey])
			-- so chooser can set default choice if null
			-- null should be valid as well
			child.value = self.values[child.formKey] or ''
		end
	end
end

function UI.Form:createForm()
	self.children = self.children or { }

	if not self.labelWidth then
		self.labelWidth = 1
		for _, child in pairs(self) do
			if type(child) == 'table' and child.UIElement then
				if child.formLabel then
					self.labelWidth = math.max(self.labelWidth, #child.formLabel + 2)
				end
			end
		end
	end

	local y = self.margin
	for _, child in pairs(self) do
		if type(child) == 'table' and child.UIElement then
			if child.formKey then
				child.value = self.values[child.formKey] or ''
			end
			if child.formLabel then
				child.x = self.labelWidth + self.margin - 1
				child.y = y
				if not child.width and not child.ex then
					child.ex = -self.margin
				end

				table.insert(self.children, UI.Text {
					x = self.margin,
					y = y,
					textColor = colors.black,
					width = #child.formLabel,
					value = child.formLabel,
				})
			end
			if child.formKey or child.formLabel then
				y = y + 1
			end
		end
	end

	if not self.manualControls then
		table.insert(self.children, UI.Button {
			y = -self.margin, x = -12 - self.margin,
			text = 'Ok',
			event = 'form_ok',
		})
		table.insert(self.children, UI.Button {
			y = -self.margin, x = -7 - self.margin,
			text = 'Cancel',
			event = 'form_cancel',
		})
	end
end

function UI.Form:validateField(field)
	if field.required then
		if not field.value or #tostring(field.value) == 0 then
			return false, 'Field is required'
		end
	end
	if field.validate == 'numeric' then
		if #tostring(field.value) > 0 then
			if not tonumber(field.value) then
				return false, 'Invalid number'
			end
		end
	end
	return true
end

function UI.Form:save()
	for _,child in pairs(self.children) do
		if child.formKey then
			local s, m = self:validateField(child)
			if not s then
				self:setFocus(child)
				self:emit({ type = 'form_invalid', message = m, field = child })
				return false
			end
		end
	end
	for _,child in pairs(self.children) do
		if child.formKey then
			if (child.pruneEmpty and type(child.value) == 'string' and #child.value == 0) or
				 (child.pruneEmpty and type(child.value) == 'boolean' and not child.value) then
				self.values[child.formKey] = nil
			elseif child.validate == 'numeric' then
				self.values[child.formKey] = tonumber(child.value)
			else
				self.values[child.formKey] = child.value
			end
		end
	end

	return true
end

function UI.Form:eventHandler(event)
	if event.type == 'form_ok' then
		if not self:save() then
			return false
		end
		self:emit({ type = self.event, UIElement = self })
	else
		return UI.Window.eventHandler(self, event)
	end
	return true
end

--[[-- Dialog --]]--
UI.Dialog = class(UI.Page)
UI.Dialog.defaults = {
	UIElement = 'Dialog',
	x = 7,
	y = 4,
	z = 2,
	height = 7,
	textColor = colors.black,
	backgroundColor = colors.white,
}
function UI.Dialog:postInit()
	self.titleBar = UI.TitleBar({ previousPage = true, title = self.title })
end

function UI.Dialog:setParent()
	if not self.width then
		self.width = self.parent.width - 11
	end
	if self.width > self.parent.width then
		self.width = self.parent.width
	end
	self.x = math.floor((self.parent.width - self.width) / 2) + 1
	self.y = math.floor((self.parent.height - self.height) / 2) + 1
	UI.Page.setParent(self)
end

function UI.Dialog:disable()
	self.previousPage.canvas.palette = self.oldPalette
	UI.Page.disable(self)
end

function UI.Dialog:enable(...)
	self.oldPalette = self.previousPage.canvas.palette
	self.previousPage.canvas:applyPalette(Canvas.darkPalette)
	self:addTransition('grow')
	UI.Page.enable(self, ...)
end

function UI.Dialog:eventHandler(event)
	if event.type == 'cancel' then
		UI:setPreviousPage()
	end
	return UI.Page.eventHandler(self, event)
end

--[[-- Image --]]--
UI.Image = class(UI.Window)
UI.Image.defaults = {
	UIElement = 'Image',
	event = 'button_press',
}
function UI.Image:setParent()
	if self.image then
		self.height = #self.image
	end
	if self.image and not self.width then
		self.width = #self.image[1]
	end
	UI.Window.setParent(self)
end

function UI.Image:draw()
	self:clear()
	if self.image then
		for y = 1, #self.image do
			local line = self.image[y]
			for x = 1, #line do
				local ch = line[x]
				if type(ch) == 'number' then
					if ch > 0 then
						self:write(x, y, ' ', ch)
					end
				else
					self:write(x, y, ch)
				end
			end
		end
	end
end

function UI.Image:setImage(image)
	self.image = image
end

--[[-- NftImage --]]--
UI.NftImage = class(UI.Window)
UI.NftImage.defaults = {
	UIElement = 'NftImage',
	event = 'button_press',
}
function UI.NftImage:setParent()
	if self.image then
		self.height = self.image.height
	end
	if self.image and not self.width then
		self.width = self.image.width
	end
	UI.Window.setParent(self)
end

function UI.NftImage:draw()
	if self.image then
		for y = 1, self.image.height do
			for x = 1, #self.image.text[y] do
				self:write(x, y, self.image.text[y][x], self.image.bg[y][x], self.image.fg[y][x])
			end
		end
	else
		self:clear()
	end
end

function UI.NftImage:setImage(image)
	self.image = image
end

UI:loadTheme('usr/config/ui.theme')
if Util.getVersion() >= 1.76 then
	UI:loadTheme('sys/etc/ext.theme')
end

UI:setDefaultDevice(UI.Device({ device = term.current() }))

return UI

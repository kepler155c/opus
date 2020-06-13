local Array      = require('opus.array')
local Blit       = require('opus.ui.blit')
local Canvas     = require('opus.ui.canvas')
local class      = require('opus.class')
local Event      = require('opus.event')
local Input      = require('opus.input')
local Transition = require('opus.ui.transition')
local Util       = require('opus.util')

local _rep       = string.rep
local colors     = _G.colors
local device     = _G.device
local fs         = _G.fs
local os         = _G.os
local term       = _G.term
local textutils  = _G.textutils

--[[
	Using the shorthand window definition, elements are created from
	the bottom up. Once reaching the top, setParent is called top down.

	On :init(), elements do not know the parent or can calculate sizing.

	Calling order:
	window:postInit()
		at this point, the window has all default values set
	window:setParent()
		parent has been assigned
		following are called:
		window:layout()
			sizing / positioning is performed
		window:initChildren()
			each child of window will get initialized
]]

--[[-- Top Level Manager --]]--
local UI = { }
function UI:init()
	self.devices = { }
	self.theme = {
		colors = {
			primary = colors.green,
			secondary = colors.lightGray,
			tertiary = colors.gray,
		}
	}
	self.extChars = Util.getVersion() >= 1.76

	local function keyFunction(event, code, held)
		local ie = Input:translate(event, code, held)

		local currentPage = self:getActivePage()
		if ie and currentPage then
			local target = currentPage.focused or currentPage
			target:emit({ type = 'key', key = ie.code == 'char' and ie.ch or ie.code, element = target, ie = ie })
			currentPage:sync()
		end
	end

	local function resize(_, side)
		local dev = self.devices[side or 'terminal']
		if dev and dev.currentPage then
			dev:resize()

			dev.currentPage:resize()
			dev.currentPage:draw()
			dev.currentPage:sync()
		end
	end

	local handlers = {
		char = keyFunction,
		key_up = keyFunction,
		key = keyFunction,
		term_resize = resize,
		monitor_resize = resize,

		mouse_scroll = function(_, direction, x, y, side)
			local ie = Input:translate('mouse_scroll', direction, x, y)

			local currentPage = self:getActivePage()
			if currentPage and currentPage.parent.device.side == side then
				local event = currentPage:pointToChild(x, y)
				event.type = ie.code
				event.ie = { code = ie.code, x = event.x, y = event.y }
				event.element:emit(event)
				currentPage:sync()
			end
		end,

		monitor_touch = function(_, side, x, y)
			local dev = self.devices[side]
			if dev and dev.currentPage then
				Input:translate('mouse_click', 1, x, y)
				local ie = Input:translate('mouse_up', 1, x, y)
				self:click(dev.currentPage, ie)
			end
		end,

		mouse_click = function(_, button, x, y, side)
			local ie = Input:translate('mouse_click', button, x, y)

			local currentPage = self:getActivePage()
			if currentPage and currentPage.parent.device.side == side then
				local event = currentPage:pointToChild(x, y)
				if event.element.focus and not event.element.inactive then
					currentPage:setFocus(event.element)
					currentPage:sync()
				end
				self:click(currentPage, ie)
			end
		end,

		mouse_up = function(_, button, x, y, side)
			local ie = Input:translate('mouse_up', button, x, y)
			local currentPage = self:getActivePage()

			if ie.code == 'control-shift-mouse_click' then -- hack
				local event = currentPage:pointToChild(x, y)
				_ENV.multishell.openTab(_ENV, {
					path = 'sys/apps/Lua.lua',
					args = { event.element, self, _ENV },
					focused = true })

			elseif ie and currentPage and currentPage.parent.device.side == side then
				self:click(currentPage, ie)
			end
		end,

		mouse_drag = function(_, button, x, y, side)
			local ie = Input:translate('mouse_drag', button, x, y)
			local currentPage = self:getActivePage()

			if ie and currentPage and currentPage.parent.device.side == side then
				self:click(currentPage, ie)
			end
		end,

		paste = function(_, text)
			local ie = Input:translate('paste', text)
			self:emitEvent({ type = 'paste', text = text, ie = ie })
			self:getActivePage():sync()
		end,
	}

	-- use 1 handler to single thread all events
	Event.on({
		'char', 'key_up', 'key', 'term_resize', 'monitor_resize',
		'mouse_scroll', 'monitor_touch', 'mouse_click',
		'mouse_up', 'mouse_drag', 'paste' },
		function(event, ...)
			handlers[event](event, ...)
		end)
end

function UI:configure(appName, ...)
	local defaults = Util.loadTable('usr/config/' .. appName) or { }
	if not defaults.device then
		defaults.device = { }
	end

	-- starting a program: gpsServer --display=monitor_3148 --scale=.5 gps
	local _, options = Util.parse(...)
	local optionValues = {
		name = options.display,
		textScale = tonumber(options.scale),
	}

	Util.merge(defaults.device, optionValues)

	if defaults.device.name then
		local dev

		if defaults.device.name == 'terminal' then
			dev = term.current()
		else
			dev = device[defaults.device.name]
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
		Util.deepMerge(self.theme, defaults.theme)
	end
end

function UI:disableEffects()
	self.term.effectsEnabled = false
end

function UI:loadTheme(filename)
	if fs.exists(filename) then
		local theme, err = Util.loadTable(filename)
		if not theme then
			error(err)
		end
		Util.deepMerge(self.theme, theme)
	end
	for k,v in pairs(self.theme.colors) do
		Canvas.colorPalette[k] = Canvas.colorPalette[v]
		Canvas.grayscalePalette[k] = Canvas.grayscalePalette[v]
	end
end

function UI:generateTheme(filename)
	local t = { }

	local function getName(d)
		if type(d) == 'string' then
			return string.format("'%s'", d)
		end
		for c, n in pairs(colors) do
			if n == d then
				return 'colors.' .. c
			end
		end
	end

	for k,v in pairs(self) do
		if type(v) == 'table' then
			if v._preload then
				v._preload()
				v = self[k]
			end
			if v.defaults and v.defaults.UIElement ~= 'Device' then
				for p,d in pairs(v.defaults) do
					if p:find('olor') then
						if not t[k] then
							t[k] = { }
						end
						t[k][p] = getName(d)
					end
				end
			end
		end
	end
	t.colors = {
		primary = getName(self.colors.primary),
		secondary = getName(self.colors.secondary),
		tertiary = getName(self.colors.tertiary),
	}
	Util.writeFile(filename, textutils.serialize(t):gsub('(")', ''))
end

function UI:emitEvent(event)
	local currentPage = self:getActivePage()
	if currentPage and currentPage.focused then
		return currentPage.focused:emit(event)
	end
end

function UI:click(target, ie)
	local clickEvent

	if ie.code == 'mouse_drag' then
		local function getPosition(element, x, y)
			repeat
				x = x - element.x + 1
				y = y - element.y + 1
				element = element.parent
			until not element
			return x, y
		end

		local x, y = getPosition(self.lastClicked, ie.x, ie.y)

		clickEvent = {
			element = self.lastClicked,
			x = x,
			y = y,
			dx = ie.dx,
			dy = ie.dy,
		}
	else
		clickEvent = target:pointToChild(ie.x, ie.y)
	end

	-- hack for dropdown menus
	if ie.code == 'mouse_click' and not clickEvent.element.focus then
		self:emitEvent({ type = 'mouse_out' })
	end

	if ie.code == 'mouse_doubleclick' then
		if self.lastClicked ~= clickEvent.element then
			return
		end
	else
		self.lastClicked = clickEvent.element
	end

	clickEvent.button = ie.button
	clickEvent.type = ie.code
	clickEvent.key = ie.code
	clickEvent.ie = { code = ie.code, x = clickEvent.x, y = clickEvent.y }
	clickEvent.raw = ie

	if clickEvent.element.focus then
		target:setFocus(clickEvent.element)
	end
	clickEvent.element:emit(clickEvent)

	target:sync()
end

function UI:setDefaultDevice(dev)
	self.term = dev
end

function UI:addPage(name, page)
	if not self.pages then
		self.pages = { }
	end
	self.pages[name] = page
end

function UI:setPages(pages)
	self.pages = pages
end

function UI:getPage(pageName)
	local page = self.pages[pageName]

	if not page then
		error('UI:getPage: Invalid page: ' .. tostring(pageName), 2)
	end

	return page
end

function UI:getActivePage(page)
	if page then
		return page.parent.currentPage
	end
	return self.term.currentPage
end

function UI:setActivePage(page)
	page.parent.currentPage = page
end

function UI:setPage(pageOrName, ...)
	local page = pageOrName

	if type(pageOrName) == 'string' then
		page = self.pages[pageOrName] or error('Invalid page: ' .. pageOrName)
	end

	local currentPage = self:getActivePage(page)
	if page == currentPage then
		page:draw()
	else
		if currentPage then
			if currentPage.focused then
				currentPage.focused.focused = false
				currentPage.focused:focus()
			end
			currentPage:disable()
			page.previousPage = currentPage
		end
		self:setActivePage(page)
		page:enable(...)
		page:draw()
		if page.focused then
			page.focused.focused = true
			page.focused:focus()
		end
		page:sync()
	end
end

function UI:getCurrentPage()
	return self.term.currentPage
end

function UI:setPreviousPage()
	if self.term.currentPage.previousPage then
		local previousPage = self.term.currentPage.previousPage.previousPage
		self:setPage(self.term.currentPage.previousPage)
		self.term.currentPage.previousPage = previousPage
	end
end

function UI:getDefaults(element, args)
	local defaults = Util.deepCopy(element.defaults)
	if args then
		UI:mergeProperties(defaults, args)
	end
	return defaults
end

function UI:mergeProperties(obj, args)
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

function UI:pullEvents(...)
	local s, m = pcall(Event.pullEvents, ...)
	self.term:reset()
	if not s and m then
		error(m, -1)
	end
end

UI.exitPullEvents = Event.exitPullEvents
UI.quit = Event.exitPullEvents
UI.start = UI.pullEvents

UI:init()

--[[-- Basic drawable area --]]--
UI.Window = class(Canvas)
UI.Window.uid = 1
UI.Window.docs = { }
UI.Window.defaults = {
	UIElement = 'Window',
	x = 1,
	y = 1,
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
		if m ~= Canvas then
			defaults = UI:getDefaults(m, defaults)
		end
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

UI.Window.docs.postInit = [[postInit(VOID)
Called once the window has all the properties set.
Override to calculate properties or to dynamically add children]]
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
				if self.enabled then
					child:enable()
				end
			end
		end
		self.children = children
	end
end

function UI.Window:layout()
	local function calc(p, max)
		p = tonumber(p:match('(%d+)%%'))
		return p and math.floor(max * p / 100) or 1
	end

	if type(self.x) == 'string' then
		self.x = calc(self.x, self.parent.width) + 1
		-- +1 in order to allow both x and ex to use the same %
	end
	if type(self.ex) == 'string' then
		self.ex = calc(self.ex, self.parent.width)
	end
	if type(self.y) == 'string' then
		self.y = calc(self.y, self.parent.height) + 1
	end
	if type(self.ey) == 'string' then
		self.ey = calc(self.ey, self.parent.height)
	end

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

	self.width = math.max(self.width, 1)
	self.height = math.max(self.height, 1)

	self:reposition(self.x, self.y, self.width, self.height)
end

-- Called when the window's parent has be assigned
function UI.Window:setParent()
	self.oh, self.ow = self.height, self.width
	self.ox, self.oy = self.x, self.y
	self.oex, self.oey = self.ex, self.ey

	self:layout()
	self:initChildren()
end

function UI.Window:resize()
	self.height, self.width = self.oh, self.ow
	self.x, self.y = self.ox, self.oy
	self.ex, self.ey = self.oex, self.oey

	self:layout()

	if self.children then
		for child in self:eachChild() do
			child:resize()
		end
	end
end

function UI.Window:reposition(x, y, w, h)
	if not self.lines then
		Canvas.init(self, {
			x = x,
			y = y,
			width = w,
			height = h,
			isColor = self.parent.isColor,
		})
	else
		self:move(x, y)
		Canvas.resize(self, w, h)
	end
end

UI.Window.docs.raise = [[raise(VOID)
Raise this window to the top]]
function UI.Window:raise()
	Array.removeByValue(self.parent.children, self)
	table.insert(self.parent.children, self)
	self:dirty(true)
end

UI.Window.docs.add = [[add(TABLE)
Add element(s) to a window. Example:
page:add({
	text = UI.Text {
	  x=5,value='help'
	}
})]]
function UI.Window:add(children)
	UI:mergeProperties(self, children)
	self:initChildren()
end

function UI.Window:eachChild()
	local c = self.children and Util.shallowCopy(self.children)
	local i = 0
	return function()
		i = i + 1
		return c and c[i]
	end
end

function UI.Window:remove()
	Array.removeByValue(self.parent.children, self)
	self.parent:dirty(true)
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
	self.cursorBlink = blink
end

UI.Window.docs.draw = [[draw(VOID)
Redraws the window in the internal buffer.]]
function UI.Window:draw()
	self:clear()
	self:drawChildren()
end

function UI.Window:drawChildren()
	for child in self:eachChild() do
		if child.enabled then
			child:draw()
		end
	end
end

UI.Window.docs.getDoc = [[getDoc(STRING method)
Get the documentation for a method.]]
function UI.Window:getDoc(method)
	local m = getmetatable(self)  -- get the class for this instance
	repeat
		if m.docs and m.docs[method] then
			return m.docs[method]
		end
		m = m._base
	until not m
end

UI.Window.docs.sync = [[sync(VOID)
Invoke a screen update. Automatically called at top level after an input event.
Call to force a screen update.]]
function UI.Window:sync()
	if self.parent then
		self.parent:sync()
	end
end

function UI.Window:enable(...)
	if not self.enabled then
		self.enabled = true
		if self.transitionHint then
			self:addTransition(self.transitionHint)
		end

		if self.modal then
			self:raise()
			self:capture(self)
		end

		for child in self:eachChild() do
			if not child.enabled then
				child:enable(...)
			end
		end
	end
end

function UI.Window:disable()
	if self.enabled then
		self.enabled = false
		self.parent:dirty(true)

		if self.modal then
			self:release(self)
		end

		for child in self:eachChild() do
			if child.enabled then
				child:disable()
			end
		end
	end
end

function UI.Window:setTextScale(textScale)
	self.textScale = textScale
	self.parent:setTextScale(textScale)
end

UI.Window.docs.clear = [[clear(opt COLOR bg, opt COLOR fg)
Clears the window using either the passed values or the defaults for that window.]]
function UI.Window:clear(bg, fg)
	Canvas.clear(self, bg or self:getProperty('backgroundColor'), fg or self:getProperty('textColor'))
end

UI.Window.docs.clearLine = [[clearLine(NUMBER y, opt COLOR bg)
Clears the specified line.]]
function UI.Window:clearLine(y, bg)
	self:write(1, y, _rep(' ', self.width), bg)
end

function UI.Window:clearArea(x, y, width, height, bg)
	self:fillArea(x, y, width, height, ' ', bg)
end

function UI.Window:fillArea(x, y, width, height, fillChar, bg, fg)
	if width > 0 then
		local filler = _rep(fillChar, width)
		for i = 0, height - 1 do
			self:write(x, y + i, filler, bg, fg)
		end
	end
end

UI.Window.docs.write = [[write(NUMBER x, NUMBER y, STRING text, opt COLOR bg, opt COLOR fg)
Write text to the canvas.
If colors are not specified, the colors from the base class will be used.
If the base class does not have colors defined, colors will be inherited from the parent container.]]
function UI.Window:write(x, y, text, bg, fg)
	Canvas.write(self, x, y, text, bg or self:getProperty('backgroundColor'), fg or self:getProperty('textColor'))
end

function UI.Window:centeredWrite(y, text, bg, fg)
	if #text >= self.width then
		self:write(1, y, text, bg, fg)
	else
		local x = math.floor((self.width-#text) / 2) + 1
		self:write(x, y, text, bg, fg)
	end
end

function UI.Window:print(text, bg, fg)
	local marginLeft = self.marginLeft or 0
	local marginRight = self.marginRight or 0
	local width = self.width - marginLeft - marginRight
	local cs = {
		bg = bg or self:getProperty('backgroundColor'),
		fg = fg or self:getProperty('textColor'),
		palette = self.palette,
	}

	local y = (self.marginTop or 0) + 1
	for _,line in pairs(Util.split(text)) do
		for _, ln in ipairs(Blit(line, cs):wrap(width)) do
			self:blit(marginLeft + 1, y, ln.text, ln.bg, ln.fg)
			y = y + 1
		end
	end
end

UI.Window.docs.focus = [[focus(VOID)
If the function is present on a class, it indicates
that this element can accept focus. Called when receiving focus.]]

UI.Window.docs.setFocus = [[setFocus(ELEMENT el)
Set the page's focus to the passed element.]]
function UI.Window:setFocus(focus)
	if self.parent then
		self.parent:setFocus(focus)
	end
end

UI.Window.docs.capture = [[capture(ELEMENT el)
Restricts input to the passed element's tree.]]
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
		for i = #self.children, 1, -1 do
			local child = self.children[i]
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

UI.Window.docs.getFocusables = [[getFocusables(VOID)
Returns a list of children that can accept focus.]]
function UI.Window:getFocusables()
	local focusable = { }

	local function focusSort(a, b)
		if a.y == b.y then
			return a.x < b.x
		end
		return a.y < b.y
	end

	local function getFocusable(parent)
		for _,child in Util.spairs(parent.children, focusSort) do
			if child.enabled and child.focus and not child.inactive then
				table.insert(focusable, child)
			end
			if child.children then
				getFocusable(child)
			end
		end
	end

	if self.children then
		getFocusable(self)
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

function UI.Window:scrollIntoView()
	local parent = self.parent
	local offx, offy = parent.offx, parent.offy

	if self.x <= parent.offx then
		parent.offx = math.max(0, self.x - 1)
		if offx ~= parent.offx then
			parent:draw()
		end
	elseif self.x + self.width > parent.width + parent.offx then
		parent.offx = self.x + self.width - parent.width - 1
		if offx ~= parent.offx then
			parent:draw()
		end
	end

	-- TODO: fix
	local function setOffset(y)
		parent.offy = y
		if offy ~= parent.offy then
			parent:draw()
		end
	end

	if self.y <= parent.offy then
		setOffset(math.max(0, self.y - 1))
	elseif self.y + self.height > parent.height + parent.offy then
		setOffset(self.y + self.height - parent.height - 1)
	end
end

function UI.Window:addTransition(effect, args, canvas)
	self.parent:addTransition(effect, args, canvas or self)
end

UI.Window.docs.emit = [[emit(TABLE event)
Send an event to the element. The event handler for the element is called.
If the event handler returns true, then no further processing is done.
If the event handler does not return true, then the event is sent to the parent element
and continues up the element tree.
If an accelerator is defined, the accelerated event is processed in the same manner.
Accelerators are useful for making events unique.]]
function UI.Window:emit(event)
	local parent = self
	while parent do
		if parent.accelerators then
			-- events types can be made unique via accelerators
			local acc = parent.accelerators[event.key or event.type]
			if acc and acc ~= event.type then -- don't get stuck in a loop
				local event2 = Util.shallowCopy(event)
				event2.type = acc
				event2.key = nil
				if parent:emit(event2) then
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

function UI.Window:getProperty(property)
	return self[property] or self.parent and self.parent:getProperty(property)
end

function UI.Window:find(uid)
	local el = self.children and Util.find(self.children, 'uid', uid)
	if not el then
		for child in self:eachChild() do
			el = child:find(uid)
			if el then
				break
			end
		end
	end
	return el
end

function UI.Window:eventHandler()
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

	if not self.device.setTextScale then
		self.device.setTextScale = function() end
	end

	self._obg = term.getBackgroundColor()
	self.device.setTextScale(self.textScale)
	self.width, self.height = self.device.getSize()
	self.isColor = self.device.isColor()
	Canvas.init(self, { isColor = self.isColor })

	UI.devices[self.device.side or 'terminal'] = self
end

function UI.Device:resize()
	self.device.setTextScale(self.textScale)
	self.width, self.height = self.device.getSize()
	self.lines = { }
	-- TODO: resize all pages added to this device
	Canvas.resize(self, self.width, self.height)
	Canvas.clear(self, self.backgroundColor, self.textColor)
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
end

function UI.Device:setTextScale(textScale)
	self.textScale = textScale
	self.device.setTextScale(self.textScale)
end

function UI.Device:reset()
	self.device.setBackgroundColor(self._obg)
	self.device.clear()
	self.device.setCursorPos(1, 1)
end

function UI.Device:addTransition(effect, args, canvas)
	if not self.transitions then
		self.transitions = { }
	end

	if type(effect) == 'string' then
		effect = Transition[effect] or error('Invalid transition')
	end

	-- there can be only one
	for k,v in pairs(self.transitions) do
		if v.canvas == canvas then
			table.remove(self.transitions, k)
			break
		end
	end

	table.insert(self.transitions, { effect = effect, args = args or { }, canvas = canvas })
end

function UI.Device:runTransitions(transitions)
	for _,k in pairs(transitions) do
		k.update = k.effect(k.canvas, k.args)
	end
	while true do
		for _,k in ipairs(Util.keys(transitions)) do
			local transition = transitions[k]
			if not transition.update() then
				transitions[k] = nil
			end
		end
		self.currentPage:render(self, true)
		if Util.empty(transitions) then
			break
		end
		os.sleep(0)
	end
end

function UI.Device:sync()
	local transitions = self.effectsEnabled and self.transitions
	self.transitions = nil

	self.device.setCursorBlink(false)

	if transitions then
		self:runTransitions(transitions)
	else
		self.currentPage:render(self, true)
	end

	if self:getCursorBlink() then
		self.device.setCursorPos(self.cursorX, self.cursorY)
		if self.isColor then
			self.device.setTextColor(colors.orange)
		end
		self.device.setCursorBlink(true)
	end
end

-- lazy load components
local function loadComponents()
	local function load(name)
		local s, m = Util.run(_ENV, 'sys/modules/opus/ui/components/' .. name .. '.lua')
		if not s then
			error(m)
		end
		if UI[name]._preload then
			error('Error loading UI.' .. name)
		end
		if UI.theme[name] and UI[name].defaults then
			Util.merge(UI[name].defaults, UI.theme[name])
		end
		return UI[name]
	end

	local components = fs.list('sys/modules/opus/ui/components')
	for _, f in pairs(components) do
		local name = f:match('(.+)%.')

		UI[name] = setmetatable({ }, {
			__call = function(self, ...)
				load(name)
				setmetatable(self, getmetatable(UI[name]))
				return self(...)
			end
		})
		UI[name]._preload = function()
			return load(name)
		end
	end
end

loadComponents()
UI:loadTheme('usr/config/ui.theme')
UI:setDefaultDevice(UI.Device())

return UI

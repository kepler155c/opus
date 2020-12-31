local History    = require('opus.history')
local UI         = require('opus.ui')
local Util       = require('opus.util')

local colors     = _G.colors
local os         = _G.os
local textutils  = _G.textutils
local term       = _G.term

local sandboxEnv = setmetatable(Util.shallowCopy(_ENV), { __index = _G })
sandboxEnv.exit = function() UI:quit() end
sandboxEnv._echo = function( ... ) return { ... } end
_G.requireInjector(sandboxEnv)

UI:configure('Lua', ...)

local command = ''
local counter = 1
local history = History.load('usr/.lua_history', 25)

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Local',  event = 'local'  },
			{ text = 'Global', event = 'global' },
			{ text = 'Device', event = 'device', name = 'Device' },
		},
	},
	prompt = UI.TextEntry {
		y = 2,
		shadowText = 'enter command',
		accelerators = {
			enter               = 'command_enter',
			up                  = 'history_back',
			down                = 'history_forward',
			mouse_rightclick    = 'clear_prompt',
			[ 'control-space' ] = 'autocomplete',
		},
	},
	tabs = UI.Tabs {
		y = 3,
		formatted = UI.Tab {
			title = 'Formatted',
			index = 1,
			grid = UI.ScrollingGrid {
				columns = {
					{ heading = 'Key',   key = 'name'  },
					{ heading = 'Value', key = 'value' },
				},
				sortColumn = 'name',
				autospace = true,
			},
		},
		output = UI.Tab {
			title = 'Output',
			index = 2,
			backgroundColor = 'black',
			output = UI.Embedded {
				y = 2,
				maxScroll = 1000,
				backgroundColor = 'black',
			},
			draw = function(self)
				self:write(1, 1, string.rep('\131', self.width), 'black', 'primary')
				self:drawChildren()
			end,
		},
	},
}

page.grid = page.tabs.formatted.grid
page.output = page.tabs.output.output

function page:setPrompt(value, focus)
	self.prompt:setValue(value)

	if value:sub(-1) == ')' then
		self.prompt:setPosition(#value - 1)
	else
		self.prompt:setPosition(#value)
	end

	self.prompt:draw()
	if focus then
		page:setFocus(self.prompt)
	end
end

function page:enable()
	UI.Page.enable(self)
	self:setFocus(self.prompt)
end

local function autocomplete(env, oLine, x)
	local sLine = oLine:sub(1, x)
	local nStartPos = sLine:find("[a-zA-Z0-9_%.]+$")
	if nStartPos then
		sLine = sLine:sub(nStartPos)
	end

	if #sLine > 0 then
		local results = textutils.complete(sLine, env)

		if #results == 1 then
			return Util.insertString(oLine, results[1], x + 1)

		elseif #results > 1 then
			local prefix = results[1]
			for n = 1, #results do
				local result = results[n]
				while #prefix > 0 do
					if result:find(prefix, 1, true) == 1 then
						break
					end
					prefix = prefix:sub(1, #prefix - 1)
				end
			end
			if #prefix > 0 then
				return Util.insertString(oLine, prefix, x + 1)
			end
		end
	end
	return oLine
end

function page:eventHandler(event)
	if event.type == 'global' then
		self:setPrompt('_G', true)
		self:executeStatement('_G')
		command = nil

	elseif event.type == 'local' then
		self:setPrompt('_ENV', true)
		self:executeStatement('_ENV')
		command = nil

	elseif event.type == 'tab_select' then
		self:setFocus(self.prompt)

	elseif event.type == 'show_output' then
		self.tabs:selectTab(self.tabs.output)

	elseif event.type == 'autocomplete' then
		local value = self.prompt.value or ''
		local sz = #value
		local pos = self.prompt.entry.pos
		self:setPrompt(autocomplete(sandboxEnv, value, self.prompt.entry.pos))
		self.prompt:setPosition(pos + #(self.prompt.value or '') - sz)
		self.prompt:updateCursor()

	elseif event.type == 'device' then
		self:setPrompt('device', true)
		self:executeStatement('device')

	elseif event.type == 'history_back' then
		local value = history:back()
		if value then
			self:setPrompt(value)
		end

	elseif event.type == 'history_forward' then
		self:setPrompt(history:forward() or '')

	elseif event.type == 'clear_prompt' then
		self:setPrompt('')
		history:reset()

	elseif event.type == 'command_enter' then
		local s = tostring(self.prompt.value or '')

		if #s > 0 then
			self:executeStatement(s)
		else
			local t = { }
			for k = #history.entries, 1, -1 do
				table.insert(t, {
					name = #t + 1,
					value = history.entries[k],
					isHistory = true,
					pos = k,
				})
			end
			history:reset()
			command = nil
			self.grid:setValues(t)
			self.grid:setIndex(1)
			self.grid:draw()
		end
		return true

	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

function page:setResult(result)
	local t = { }

	local function safeValue(v)
		if type(v) == 'string' or type(v) == 'number' then
			return v
		end
		return tostring(v)
	end

	if type(result) == 'table' then
		for k,v in pairs(result) do
			local entry = {
				name = safeValue(k),
				rawName = k,
				value = safeValue(v),
				rawValue = v,
			}
			if type(v) == 'table' then
				if Util.size(v) == 0 then
					entry.value = 'table: (empty)'
				else
					entry.value = tostring(v)
				end
			end
			table.insert(t, entry)
		end
	else
		table.insert(t, {
			name = type(result),
			value = tostring(result),
			rawValue = result,
		})
	end
	self.grid:setValues(t)
	self.grid:setIndex(1)
	self.grid:draw()
end

function page.grid:eventHandler(event)
	local entry = self:getSelected()

	local function commandAppend()
		if entry.isHistory then
			--history.setPosition(entry.pos)
			return entry.value
		end
		if type(entry.rawValue) == 'function' then
			if command then
				 return command .. '.' .. entry.name .. '()'
			end
			return entry.name .. '()'
		end
		if command then
			if type(entry.rawName) == 'number' then
				return command .. '[' .. entry.name .. ']'
			end
			if entry.name:match("%W") or
				 entry.name:sub(1, 1):match("%d") then
				return command .. "['" .. tostring(entry.name) .. "']"
			end
			return command .. '.' .. entry.name
		end
		return entry.name
	end

	if event.type == 'grid_focus_row' then
		if self.focused then
			page:setPrompt(commandAppend())
		end
	elseif event.type == 'grid_select' then
		page:setPrompt(commandAppend(), true)
		page:executeStatement(commandAppend())

	elseif event.type == 'copy' then
		if entry then
			os.queueEvent('clipboard_copy', entry.rawValue)
		end
	else
		return UI.ScrollingGrid.eventHandler(self, event)
	end
	return true
end

function page:rawExecute(s)
	local fn, m
	local wrapped

	fn = load('return (' ..s.. ')', 'lua', nil, sandboxEnv)

	if fn then
		fn = load('return {' ..s.. '}', 'lua', nil, sandboxEnv)
		wrapped = true
	end

	local t = os.clock()
	if fn then
		fn, m = pcall(fn)
		if #m <= 1 and wrapped then
			m = m[1]
		end
	else
		fn, m = load(s, 'lua', nil, sandboxEnv)
		if fn then
			t = os.clock()
			fn, m = pcall(fn)
		end
	end

	if fn then
		t = os.clock() - t

		local bg, fg = term.getBackgroundColor(), term.getTextColor()
		term.setTextColor(colors.cyan)
		term.setBackgroundColor(colors.black)
		term.write(string.format('out [%.2f]: ', t))
		term.setBackgroundColor(bg)
		term.setTextColor(fg)
		if m or wrapped then
			Util.print(m or 'nil')
		else
			print()
		end
	else
		_G.printError(m)
	end

	return fn, m
end

function page:executeStatement(statement)
	command = statement

	history:add(statement)
	history:back()

	local s, m
	local oterm = term.redirect(self.output.win)
	self.output.win.scrollBottom()
	local bg, fg = term.getBackgroundColor(), term.getTextColor()
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.green)
	term.write(string.format('in [%d]: ', counter))
	term.setBackgroundColor(bg)
	term.setTextColor(fg)
	print(tostring(statement))

	pcall(function()
		s, m = self:rawExecute(command)
	end)

	term.redirect(oterm)
	counter = counter + 1

	if s and type(m) ~= "nil" then
		self:setResult(m)
	else
		self.grid:setValues({ })
		self.grid:draw()
		if m and not self.output.enabled then
			self:emit({ type = 'show_output' })
		end
	end
end

local args = Util.parse(...)
if args[1] then
	command = 'args[1]'
	sandboxEnv.args = args
	page:setResult(args[1])
	page:setPrompt(command)
end

UI:setPage(page)
UI:start()

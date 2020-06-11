local Array    = require('opus.array')
local Terminal = require('opus.terminal')
local trace    = require('opus.trace')
local Util     = require('opus.util')

_G.kernel = {
	UID = 0,
	hooks = { },
	routines = { },
}

local fs     = _G.fs
local kernel = _G.kernel
local os     = _G.os
local shell  = _ENV.shell
local term   = _G.term
local window = _G.window

local w, h = term.getSize()
kernel.terminal = term.current()

kernel.window = Terminal.window(kernel.terminal, 1, 1, w, h, false)
kernel.window.setMaxScroll(200)

local focusedRoutineEvents = Util.transpose {
	'char', 'key', 'key_up',
	'mouse_click', 'mouse_drag', 'mouse_scroll', 'mouse_up',
	'paste', 'terminate',
}

_G._syslog = function(pattern, ...)
	kernel.window.scrollBottom()
	kernel.window.print(Util.tostring(pattern, ...))
end

-- any function that runs in a kernel hook does not run in
-- a separate coroutine or have a window. an error in a hook
-- function will crash the system.
function kernel.hook(event, fn)
	if type(event) == 'table' then
		for _,v in pairs(event) do
			kernel.hook(v, fn)
		end
	else
		if not kernel.hooks[event] then
			kernel.hooks[event] = { }
		end
		table.insert(kernel.hooks[event], fn)
	end
end

-- you *should* only unhook from within the function that hooked
function kernel.unhook(event, fn)
	if type(event) == 'table' then
		for _,v in pairs(event) do
			kernel.unhook(v, fn)
		end
	else
		local eventHooks = kernel.hooks[event]
		if eventHooks then
			Array.removeByValue(eventHooks, fn)
			if #eventHooks == 0 then
				kernel.hooks[event] = nil
			end
		end
	end
end

local function switch(routine, previous)
	if routine then
		if previous and previous.window then
			previous.window.setVisible(false)
			if previous.hidden then
				kernel.lower(previous.uid)
			end
		end

		if routine and routine.window then
			routine.window.setVisible(true)
		end

		os.queueEvent('kernel_focus', routine.uid, previous and previous.uid)
	end
end

local Routine = { }

function Routine:resume(event, ...)
	if not self.co or coroutine.status(self.co) == 'dead' then
		return
	end

	if not self.filter or self.filter == event or event == "terminate" then
		local previousTerm = term.redirect(self.terminal)

		local previous = kernel.running
		kernel.running = self
		local ok, result = coroutine.resume(self.co, event, ...)
		kernel.running = previous

		self.filter = result
		self.terminal = term.current()
		term.redirect(previousTerm)

		return ok, result
	end
end

function Routine:run()
	self.co = self.co or coroutine.create(function()
		local result, err, fn, stack

		if self.fn then
			fn = self.fn
			_G.setfenv(fn, self.env)
		elseif self.path then
			fn, err = loadfile(self.path, self.env)
		elseif self.chunk then
			fn, err = load(self.chunk, self.title, nil, self.env)
		end

		if fn then
			result, err, stack = trace(fn, table.unpack(self.args or { } ))
		else
			err = err or 'kernel: invalid routine'
		end

		pcall(self.onExit, self, result, err, stack)
		self:cleanup()

		if not result then
			error(err)
		end
	end)

	table.insert(kernel.routines, self)

	return self:resume()
end

-- override if any post processing is required
function Routine:onExit(status, message) -- self, status, message
	if not status and message ~= 'Terminated' then
		_G.printError(message)
	end
end

function Routine:cleanup()
	Array.removeByValue(kernel.routines, self)
	if #kernel.routines > 0 then
		switch(kernel.routines[1])
	end
end

function kernel.getFocused()
	return kernel.routines[1]
end

function kernel.getCurrent()
	return kernel.running
end

function kernel.getShell()
	return shell
end

-- each routine inherits the parent's env
function kernel.makeEnv(env, dir)
	env = setmetatable(Util.shallowCopy(env or _ENV), { __index = _G })
	_G.requireInjector(env, dir)
	return env
end

function kernel.newRoutine(env, args)
	kernel.UID = kernel.UID + 1

	local routine = setmetatable({
		uid = kernel.UID,
		timestamp = os.clock(),
		window = kernel.window,
		title = 'untitled',
	}, { __index = Routine })

	Util.merge(routine, args)
	routine.env = args.env or kernel.makeEnv(env, routine.path and fs.getDir(routine.path))
	routine.terminal = routine.terminal or routine.window

	return routine
end

function kernel.run(env, args)
	local routine = kernel.newRoutine(env, args)
	local s, m = routine:run()
	return s and routine, m
end

function kernel.raise(uid)
	if kernel.getFocused() and kernel.getFocused().pinned then
		return false
	end

	local routine = Util.find(kernel.routines, 'uid', uid)

	if routine then
		local previous = kernel.routines[1]
		if routine ~= previous then
			Array.removeByValue(kernel.routines, routine)
			table.insert(kernel.routines, 1, routine)
		end

		switch(routine, previous)
		return true
	end
	return false
end

function kernel.lower(uid)
	local routine = Util.find(kernel.routines, 'uid', uid)

	if routine and #kernel.routines > 1 then
		if routine == kernel.routines[1] then
			local nextRoutine = kernel.routines[2]
			if nextRoutine then
				kernel.raise(nextRoutine.uid)
			end
		end

		Array.removeByValue(kernel.routines, routine)
		table.insert(kernel.routines, routine)
		return true
	end
	return false
end

function kernel.find(uid)
	return Util.find(kernel.routines, 'uid', uid)
end

function kernel.halt(status, message)
	os.queueEvent('kernel_halt', status, message)
end

function kernel.event(event, eventData)
	local stopPropagation

	local eventHooks = kernel.hooks['*']
	if eventHooks then
		for i = #eventHooks, 1, -1 do
			stopPropagation = eventHooks[i](event, eventData)
			if stopPropagation then
				break
			end
		end
	end

	eventHooks = kernel.hooks[event]
	if eventHooks then
		for i = #eventHooks, 1, -1 do
			stopPropagation = eventHooks[i](event, eventData)
			if stopPropagation then
				break
			end
		end
	end

	if not stopPropagation then
		if focusedRoutineEvents[event] then
			local active = kernel.routines[1]
			if active then
				active:resume(event, table.unpack(eventData))
			end
		else
			-- Passthrough to all processes
			for _,routine in pairs(Util.shallowCopy(kernel.routines)) do
				routine:resume(event, table.unpack(eventData))
			end
		end
	end
end

function kernel.start()
	local s, m
	local s2, m2 = pcall(function()
		repeat
			local eventData = { os.pullEventRaw() }
			local event = table.remove(eventData, 1)
			kernel.event(event, eventData)
			if event == 'kernel_halt' then
				s = eventData[1]
				m = eventData[2]
			end
		until event == 'kernel_halt'
	end)

	if (not s and m) or (not s2 and m2) then
		kernel.window.setVisible(true)
		term.redirect(kernel.window)
		print('\nCrash detected\n')
		_G.printError(m or m2)
	end
	term.redirect(kernel.terminal)
end

local function init(...)
	local args = { ... }

	local runLevel = #args > 0 and 6 or 7

	print('Starting Opus OS')
	local dir = 'sys/init'
	local files = fs.list(dir)
	table.sort(files)
	for _,file in ipairs(files) do
		local level = file:match('(%d).%S+.lua') or 99
		if tonumber(level) <= runLevel then
			-- All init programs run under the original shell
			local s, m = shell.run(fs.combine(dir, file))
			if not s then
				error(m, -1)
			end
			os.sleep(0)
		end
	end

	os.queueEvent('kernel_ready')

	if args[1] then
		kernel.hook('kernel_ready', function()

			term.redirect(kernel.window)
			shell.run('sys/apps/autorun.lua')

			local win = window.create(kernel.terminal, 1, 1, w, h, true)
			local s, m = kernel.run(_ENV, {
				title = args[1],
				path = 'sys/apps/shell.lua',
				args = args,
				window = win,
				onExit = function(_, s, m)
					kernel.halt(s, m)
				end,
			})
			if s then
				kernel.raise(s.uid)
			else
				error(m)
			end
		end)
	end
end

kernel.run(_ENV, {
	fn = init,
	title = 'init',
	args = { ... },
	onExit = function(_, status, message)
		if not status then
			kernel.halt(status, message)
		end
	end,
})

kernel.start()

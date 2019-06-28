_G.requireInjector(_ENV)

local Terminal = require('opus.terminal')
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
kernel.window.setMaxScroll(100)

local focusedRoutineEvents = Util.transpose {
	'char', 'key', 'key_up',
	'mouse_click', 'mouse_drag', 'mouse_scroll', 'mouse_up',
	'paste', 'terminate',
}

_G._syslog = function(pattern, ...)
	local oldTerm = term.redirect(kernel.window)
	kernel.window.scrollBottom()
	Util.print(pattern, ...)
	term.redirect(oldTerm)
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

-- you can only unhook from within the function that hooked
function kernel.unhook(event, fn)
	local eventHooks = kernel.hooks[event]
	if eventHooks then
		Util.removeByValue(eventHooks, fn)
		if #eventHooks == 0 then
			kernel.hooks[event] = nil
		end
	end
end

local Routine = { }

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

function Routine:resume(event, ...)
	if not self.co or coroutine.status(self.co) == 'dead' then
		return
	end

	if not self.filter or self.filter == event or event == "terminate" then
		local previousTerm = term.redirect(self.terminal)

		local previous = kernel.running
		kernel.running = self -- stupid shell set title
		local ok, result = coroutine.resume(self.co, event, ...)
		kernel.running = previous

		if ok then
			self.filter = result
		else
			_G.printError(result)
		end

		self.terminal = term.current()
		term.redirect(previousTerm)

		if not ok and self.haltOnError then
			error(result, -1)
		end
		if coroutine.status(self.co) == 'dead' then
			Util.removeByValue(kernel.routines, self)
			if #kernel.routines > 0 then
				switch(kernel.routines[1])
			end
			if self.haltOnExit then
				kernel.halt()
			end
		end
		return ok, result
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

function kernel.newRoutine(args)
	kernel.UID = kernel.UID + 1

	local routine = setmetatable({
		uid = kernel.UID,
		timestamp = os.clock(),
		terminal = kernel.window,
		window = kernel.window,
		title = 'untitled',
	}, { __index = Routine })

	Util.merge(routine, args)
	routine.env = args.env or Util.shallowCopy(shell.getEnv())

	return routine
end

function kernel.launch(routine)
	routine.co = routine.co or coroutine.create(function()
		local result, err

		if routine.fn then
			result, err = Util.runFunction(routine.env, routine.fn, table.unpack(routine.args or { } ))
		elseif routine.path then
			result, err = Util.run(routine.env, routine.path, table.unpack(routine.args or { } ))
		else
			err = 'kernel: invalid routine'
		end

		if not result and err ~= 'Terminated' then
			error(err or 'Error occurred', 2)
		end
	end)

	table.insert(kernel.routines, routine)

	local s, m = routine:resume()

	return not s and s or routine.uid, m
end

function kernel.run(args)
	local routine = kernel.newRoutine(args)
	kernel.launch(routine)
	return routine
end

function kernel.raise(uid)
	local routine = Util.find(kernel.routines, 'uid', uid)

	if routine then
		local previous = kernel.routines[1]
		if routine ~= previous then
			Util.removeByValue(kernel.routines, routine)
			table.insert(kernel.routines, 1, routine)
		end

		switch(routine, previous)
--		local previous = eventData[2]
--			local routine = kernel.find(previous)
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

		Util.removeByValue(kernel.routines, routine)
		table.insert(kernel.routines, routine)
		return true
	end
	return false
end

function kernel.find(uid)
	return Util.find(kernel.routines, 'uid', uid)
end

function kernel.halt()
	os.queueEvent('kernel_halt')
end

function kernel.event(event, eventData)
	local stopPropagation

	local eventHooks = kernel.hooks[event]
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
	local s, m = pcall(function()
		repeat
			local eventData = { os.pullEventRaw() }
			local event = table.remove(eventData, 1)
			kernel.event(event, eventData)
		until event == 'kernel_halt'
	end)

	if not s then
		kernel.window.setVisible(true)
		term.redirect(kernel.window)
		print('\nCrash detected\n')
		_G.printError(m)
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
			local s, m = shell.run(fs.combine(dir, file))
			if not s then
				error(m)
			end
			os.sleep(0)
		end
	end

	os.queueEvent('kernel_ready')

	if args[1] then
		kernel.hook('kernel_ready', function()

			term.redirect(kernel.window)
			shell.run('sys/apps/autorun.lua')

			local shellWindow = window.create(kernel.terminal, 1, 1, w, h, false)
			local s, m = kernel.run({
				title = args[1],
				path = 'sys/apps/shell.lua',
				args = args,
				haltOnExit = true,
				haltOnError = true,
				terminal = shellWindow,
				window = shellWindow,
			})
			if s then
				kernel.raise(s.uid)
			else
				error(m)
			end
		end)
	end
end

kernel.run({
	fn = init,
	title = 'init',
	haltOnError = true,
	args = { ... },
})

kernel.start()

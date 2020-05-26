local os    = _G.os
local table = _G.table

local Event = {
	uid       = 1,       -- unique id for handlers
	routines  = { },     -- coroutines
	types     = { },     -- event handlers
	terminate = false,
	free      = { },     -- allocated unused coroutines
}

-- Use a pool of coroutines for event handlers
local function createCoroutine(h)
	local co = table.remove(Event.free)
	if not co then
		co = coroutine.create(function(_, ...)
			local args = { ... }
			while true do
				h.fn(table.unpack(args))
				h.co = nil
				table.insert(Event.free, co)
				args = { coroutine.yield() }
				h = table.remove(args, 1)
				h.co = co
			end
		end)
	end
	h.primeCo = true -- TODO: fix...
	return co
end

local Routine = { }

function Routine:isDead()
	if not self.co then
		return true
	end
	return coroutine.status(self.co) == 'dead'
end

function Routine:terminate()
	if self.co then
		self:resume('terminate')
	end
end

function Routine:resume(event, ...)
	if not self.co then
		error('Cannot resume a dead routine')
	end

	if not self.filter or self.filter == event or event == "terminate" then
		local s, m
		if self.primeCo then
			-- Only need self passed when using a coroutine from the pool
			s, m = coroutine.resume(self.co, self, event, ...)
			self.primeCo = nil
		else
			s, m = coroutine.resume(self.co, event, ...)
		end

		if not s and event ~= 'terminate' then
			if m and type(debug) == 'table' and debug.traceback then
				local t = (debug.traceback(self.co, 1)) or ''
				m = m .. '\n' .. t:match('%d\n(.+)')
			end
		end

		if self:isDead() then
			self.co = nil
			self.filter = nil
			Event.routines[self.uid] = nil
		else
			self.filter = m
		end

		if not s and event ~= 'terminate' then
			error(m or 'Error processing event', -1)
		end

		return s, m
	end

	return true, self.filter
end

local function nextUID()
	Event.uid = Event.uid + 1
	return Event.uid - 1
end

function Event.on(events, fn)
	events = type(events) == 'table' and events or { events }

	local handler = setmetatable({
		uid     = nextUID(),
		event   = events,
		fn      = fn,
	}, { __index = Routine })

	for _,event in pairs(events) do
		local handlers = Event.types[event]
		if not handlers then
			handlers = { }
			Event.types[event] = handlers
		end

		handlers[handler.uid] = handler
	end

	return handler
end

function Event.off(h)
	if h and h.event then
		for _,event in pairs(h.event) do
			local handler = Event.types[event][h.uid]
			if handler then
				handler:terminate()
			end
			Event.types[event][h.uid] = nil
		end
	elseif h and h.co then
		h:terminate()
	end
end

function Event.onInterval(interval, fn)
	local h = Event.addRoutine(function()
		while true do
			os.sleep(interval)
			fn()
		end
	end)
	function h.updateInterval(i)
		interval = i
	end
	return h
end

function Event.onTimeout(timeout, fn)
	local timerId = os.startTimer(timeout)
	local handler

	handler = Event.on('timer', function(t, id)
		if timerId == id then
			fn(t, id)
			Event.off(handler)
		end
	end)

	return handler
end

-- Set a handler for the terminate event. Within the function, return
-- true or false to indicate whether the event should be propagated to
-- all sub-threads
function Event.onTerminate(fn)
	Event.termFn = fn
end

function Event.termFn()
	Event.terminate = true
	return true -- propagate
end

function Event.addRoutine(fn)
	local r = setmetatable({
		co  = coroutine.create(fn),
		uid = nextUID()
	}, { __index = Routine })

	Event.routines[r.uid] = r
	r:resume()

	return r
end

function Event.pullEvents(...)
	for _, fn in ipairs({ ... }) do
		Event.addRoutine(fn)
	end

	repeat
		Event.pullEvent()
	until Event.terminate

	Event.terminate = false
end

function Event.exitPullEvents()
	Event.terminate = true
	os.sleep(0)
end

local function processHandlers(event)
	local handlers = Event.types[event]
	if handlers then
		for _,h in pairs(handlers) do
			if not h.co then
				-- callbacks are single threaded (only 1 co per handler)
				h.co = createCoroutine(h)
				Event.routines[h.uid] = h
			end
		end
	end
end

local function tokeys(t)
	local keys = { }
	for k in pairs(t) do
		keys[#keys+1] = k
	end
	return keys
end

local function processRoutines(...)
	local keys = tokeys(Event.routines)
	for _,key in ipairs(keys) do
		local r = Event.routines[key]
		if r then
			r:resume(...)
		end
	end
end

-- invoke the handlers registered for this event
function Event.trigger(event, ...)
	local handlers = Event.types[event]
	if handlers then
		for _,h in pairs(handlers) do
			if not h.co then
				-- callbacks are single threaded (only 1 co per handler)
				h.co = createCoroutine(h)
				Event.routines[h.uid] = h
				h:resume(event, ...)
			end
		end
	end
end

function Event.processEvent(e)
	processHandlers(e[1])
	processRoutines(table.unpack(e))
end

function Event.pullEvent(eventType)
	while true do
		local e = { os.pullEventRaw() }
		local propagate = true           -- don't like this...

		if e[1] == 'terminate' then
			propagate = Event.termFn()
		end

		if propagate then
			processHandlers(e[1])
			processRoutines(table.unpack(e))
		end

		if Event.terminate then
			return { 'terminate' }
		end

		if not eventType or e[1] == eventType then
			return e
		end
	end
end

return Event

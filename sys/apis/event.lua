local os = _G.os

local Event = {
	uid       = 1,       -- unique id for handlers
	routines  = { },     -- coroutines
	types     = { },     -- event handlers
	timers    = { },     -- named timers
	terminate = false,
}

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
	--if coroutine.status(self.co) == 'running' then
		--return
	--end

	if not self.co then
		error('Cannot resume a dead routine')
	end

	if not self.filter or self.filter == event or event == "terminate" then
		local s, m = coroutine.resume(self.co, event, ...)

		if coroutine.status(self.co) == 'dead' then
			self.co = nil
			self.filter = nil
			Event.routines[self.uid] = nil
		else
			self.filter = m
		end

		if not s and event ~= 'terminate' then
			error('\n' .. (m or 'Error processing event'))
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
			Event.types[event][h.uid] = nil
		end
	end
end

local function addTimer(interval, recurring, fn)
	local timerId = os.startTimer(interval)
	local handler

	handler = Event.on('timer', function(t, id)
		if timerId == id then
			fn(t, id)
			if recurring then
				timerId = os.startTimer(interval)
			else
				Event.off(handler)
			end
		end
	end)

	return handler
end

function Event.onInterval(interval, fn)
	return addTimer(interval, true, fn)
end

function Event.onTimeout(timeout, fn)
	return addTimer(timeout, false, fn)
end

function Event.addNamedTimer(name, interval, recurring, fn)
	Event.cancelNamedTimer(name)
	Event.timers[name] = addTimer(interval, recurring, fn)
end

function Event.cancelNamedTimer(name)
	local timer = Event.timers[name]
	if timer then
		Event.off(timer)
	end
end

function Event.waitForEvent(event, timeout)
	local timerId = os.startTimer(timeout)
	repeat
		local e = { os.pullEvent() }
		if e[1] == event then
			return table.unpack(e)
		end
	until e[1] == 'timer' and e[2] == timerId
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
				h.co = coroutine.create(h.fn)
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

function Event.processEvent(e)
	processHandlers(e[1])
	processRoutines(table.unpack(e))
end

function Event.pullEvent(eventType)
	while true do
		local e = { os.pullEventRaw() }

		Event.terminate = Event.terminate or e[1] == 'terminate'

		processHandlers(e[1])
		processRoutines(table.unpack(e))

		if Event.terminate then
			return { 'terminate' }
		end

		if not eventType or e[1] == eventType then
			return e
		end
	end
end

return Event

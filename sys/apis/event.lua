local Util = require('util')

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

  if not self.co then
    debug(event)
    debug(self)
    debug(getfenv(1))
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
      debug({s, m})
      debug(self)
      debug(getfenv(1))
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

function Event.on(event, fn)

  local handlers = Event.types[event]
  if not handlers then
    handlers = { }
    Event.types[event] = handlers
  end

  local handler = {
    uid     = nextUID(),
    event   = event,
    fn      = fn,
  }
  handlers[handler.uid] = handler
  setmetatable(handler, { __index = Routine })

  return handler
end

function Event.off(h)
  if h and h.event then
    Event.types[h.event][h.uid] = nil
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
  local r = {
    co  = coroutine.create(fn), 
    uid = nextUID()
  }
  setmetatable(r, { __index = Routine })
  Event.routines[r.uid] = r

  r:resume()

  return r
end

function Event.pullEvents(...)

  for _, fn in ipairs({ ... }) do
    Event.addRoutine(fn)
  end

  repeat
    local e = Event.pullEvent()
  until e[1] == 'terminate'
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

local function processRoutines(...)

  local keys = Util.keys(Event.routines)
  for _,key in ipairs(keys) do
    local r = Event.routines[key]
    if r then
      r:resume(...)
    end
  end
end

function Event.pullEvent(eventType)

  while true do
    local e = { os.pullEventRaw() }

    processHandlers(e[1])
    processRoutines(table.unpack(e))

    if Event.terminate or e[1] == 'terminate' then
      Event.terminate = false
      return { 'terminate' }
    end

    if not eventType or e[1] == eventType then
      return e
    end
  end
end

return Event

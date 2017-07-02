local Util = require('util')
local Process = require('process')

local Event = {
  uid = 1,  -- unique id for handlers
}

local eventHandlers = {
  namedTimers = {}
}

-- debug purposes
function Event.getHandlers()
  return eventHandlers
end

function Event.addHandler(type, f)
  local event = eventHandlers[type]
  if not event then
    event = {}
    event.handlers = {}
    eventHandlers[type] = event
  end

  local handler = {
    uid     = Event.uid,
    event   = type,
    f       = f,
  }
  Event.uid = Event.uid + 1
  event.handlers[handler.uid] = handler

  return handler
end

function Event.removeHandler(h)
  if h and h.event then
    eventHandlers[h.event].handlers[h.uid] = nil
  end
end

function Event.queueTimedEvent(name, timeout, event, args)
  Event.addNamedTimer(name, timeout, false,
    function()
      os.queueEvent(event, args)
    end
  )
end

function Event.addNamedTimer(name, interval, recurring, f)
  Event.cancelNamedTimer(name)
  eventHandlers.namedTimers[name] = Event.addTimer(interval, recurring, f)
end

function Event.getNamedTimer(name)
  return eventHandlers.namedTimers[name]
end

function Event.cancelNamedTimer(name)
  local timer = Event.getNamedTimer(name)
  if timer then
    timer.enabled = false
    Event.removeHandler(timer)
  end
end

function Event.isTimerActive(timer)
  return timer.enabled and
    os.clock() < timer.start + timer.interval
end

function Event.addTimer(interval, recurring, f)
  local timer = Event.addHandler('timer',
    function(t, id)
      if t.timerId ~= id then
        return
      end
      if t.enabled then
        t.fired = true
        t.cf(t, id)
      end
      if t.recurring then
        t.fired = false
        t.start = os.clock()
        t.timerId = os.startTimer(t.interval)
      else
        Event.removeHandler(t)
      end
    end
  )
  timer.cf = f
  timer.interval = interval
  timer.recurring = recurring
  timer.start = os.clock()
  timer.enabled = true
  timer.timerId = os.startTimer(interval)

  return timer
end

function Event.removeTimer(h)
  Event.removeHandler(h)
end

function Event.blockUntilEvent(event, timeout)
  return Event.waitForEvent(event, timeout, os.pullEvent)
end

function Event.waitForEvent(event, timeout, pullEvent)
  pullEvent = pullEvent or Event.pullEvent

  local timerId = os.startTimer(timeout)
  repeat
    local e, p1, p2, p3, p4 = pullEvent()
    if e == event then
      return e, p1, p2, p3, p4
    end 
  until e == 'timer' and p1 == timerId
end

local exitPullEvents = false

local function _pullEvents()
  while true do
    local e = { os.pullEvent() }
    Event.processEvent(e)
  end
end

function Event.sleep(t)
  local timerId = os.startTimer(t or 0)
  repeat
    local event, id = Event.pullEvent()
  until event == 'timer' and id == timerId
end

function Event.addThread(fn)
  return Process:addThread(fn)
end

function Event.pullEvents(...)
  local routines = { ... }
  if #routines > 0 then
    Process:addThread(_pullEvents)
    for _, routine in ipairs(routines) do
      Process:addThread(routine)
    end
    while true do
      local e = Process:pullEvent()
      if exitPullEvents or e == 'terminate' then
        break
      end
    end
  else
  while true do
    local e = { os.pullEventRaw() }
      Event.processEvent(e)
      if exitPullEvents or e[1] == 'terminate' then
        break
      end
    end
  end
end

function Event.exitPullEvents()
  exitPullEvents = true
  os.sleep(0)
end

function Event.pullEvent(eventType)
  local e = { os.pullEventRaw(eventType) }
  return Event.processEvent(e)
end

function Event.processEvent(pe)

  local e, p1, p2, p3, p4, p5 = unpack(pe)

  local event = eventHandlers[e]
  if event then
    local keys = Util.keys(event.handlers)
    for _,key in pairs(keys) do
      local h = event.handlers[key]
      if h then
        h.f(h, p1, p2, p3, p4, p5)
      end
    end
  end
  
  return e, p1, p2, p3, p4, p5
end

return Event

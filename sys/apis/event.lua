local Util = require('util')

local Event = {
  uid = 1,  -- unique id for handlers
  routines = { },
  handlers = { namedTimers = { } },
  terminate = false,
}

function Event.addHandler(type, f)
  local event = Event.handlers[type]
  if not event then
    event = { handlers = { } }
    Event.handlers[type] = event
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
    Event.handlers[h.event].handlers[h.uid] = nil
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
  Event.handlers.namedTimers[name] = Event.addTimer(interval, recurring, f)
end

function Event.getNamedTimer(name)
  return Event.handlers.namedTimers[name]
end

function Event.cancelNamedTimer(name)
  local timer = Event.getNamedTimer(name)
  if timer then
    timer.enabled = false
    Event.removeHandler(timer)
  end
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
        t.timerId = os.startTimer(t.interval)
      else
        Event.removeHandler(t)
      end
    end
  )
  timer.cf = f
  timer.interval = interval
  timer.recurring = recurring
  timer.enabled = true
  timer.timerId = os.startTimer(interval)

  return timer
end

function Event.onInterval(interval, f)
  return Event.addTimer(interval, true, f)
end

function Event.onTimeout(timeout, f)
  return Event.addTimer(timeout, false, f)
end

function Event.waitForEvent(event, timeout)
  local timerId = os.startTimer(timeout)
  repeat
    local e, p1, p2, p3, p4 = os.pullEvent()
    if e == event then
      return e, p1, p2, p3, p4
    end 
  until e == 'timer' and p1 == timerId
end

function Event.addRoutine(routine)
  local r = { co = coroutine.create(routine) }
  local s, m = coroutine.resume(r.co)
  if not s then
    error(m or 'Error processing routine')
  end
  Event.routines[r] = true
  r.filter = m
  return r
end

function Event.pullEvents(...)

  for _, r in ipairs({ ... }) do
    Event.addRoutine(r)
  end

  repeat
    local e = Event.pullEvent()
  until e[1] == 'terminate'
end

function Event.exitPullEvents()
  Event.terminate = true
  os.sleep(0)
end

function Event.pullEvent(eventType)

  while true do
    local e = { os.pullEventRaw() }
    local routines = Util.keys(Event.routines)
    for _, r in ipairs(routines) do
      if not r.filter or r.filter == e[1] then
        local s, m = coroutine.resume(r.co, table.unpack(e))
        if not s and e[1] ~= 'terminate' then
          debug({s, m})
          debug(r)
          error(m or 'Error processing event')
        end
        if coroutine.status(r.co) == 'dead' then
          r.co = nil
          Event.routines[r] = nil
        else
          r.filter = m
        end
      end
    end
    Event.processEvent(e)
    if Event.terminate or e[1] == 'terminate' then
      Event.terminate = false
      return { 'terminate' }
    end

    if not eventType or e[1] == eventType then
      return e
    end
  end
end

function Event.processEvent(pe)

  local e, p1, p2, p3, p4, p5 = unpack(pe)

  local event = Event.handlers[e]
  if event then
    local keys = Util.keys(event.handlers)
    for _,key in pairs(keys) do
      local h = event.handlers[key]
      if h and not h.co then
        local co = coroutine.create(function()
          h.f(h, p1, p2, p3, p4, p5)
        end)
        local s, m = coroutine.resume(co)
        if not s then
          debug({s, m})
          debug(h)
          error(m or 'Error processing ' .. e)
        elseif coroutine.status(co) ~= 'dead' then
          h.co = co
          h.filter = m
          Event.routines[h] = true
        end
      end
    end
  end

  return e, p1, p2, p3, p4, p5
end

Event.on = Event.addHandler
Event.off = Event.removeHandler

return Event

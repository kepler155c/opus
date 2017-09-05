if not turtle then
  return
end

requireInjector(getfenv(1))

local Util = require('util')

local Scheduler = {
  uid = 0,
  queue = { },
  idle = true,
}

function turtle.abortAction()
  if turtle.status ~= 'idle' then
    turtle.abort = true
    os.queueEvent('turtle_abort')
  end
  Util.clear(Scheduler.queue)
  os.queueEvent('turtle_ticket', 0, true)
end

local function getTicket(fn, ...)
  Scheduler.uid = Scheduler.uid + 1

  if Scheduler.idle then
    Scheduler.idle = false
    turtle.status = 'busy'
    os.queueEvent('turtle_ticket', Scheduler.uid)
  else
    table.insert(Scheduler.queue, Scheduler.uid)
  end

  return Scheduler.uid
end

local function releaseTicket(id)
  for k,v in ipairs(Scheduler.queue) do
    if v == id then
      table.remove(Scheduler.queue, k)
      return
    end
  end
  local id = table.remove(Scheduler.queue, 1)
  if id then
    os.queueEvent('turtle_ticket', id)
  else
    Scheduler.idle = true
    turtle.status = 'idle'
  end
end

function turtle.run(fn, ...)
  local ticketId = getTicket()

  if type(fn) == 'string' then
    fn = turtle[fn]
  end
  while true do
    local e, id, abort = os.pullEventRaw('turtle_ticket')
    if e == 'terminate' then
      releaseTicket(ticketId)
      os.queueEvent('turtle_response')
      error('Terminated')
    end
    if abort then
      -- the function was queued, but the queue was cleared
      os.queueEvent('turtle_response')
      return false, 'aborted'
    end
    if id == ticketId then
      turtle.abort = false
      turtle.resetState()
      local args = { ... }
      local s, m = pcall(function() fn(unpack(args)) end)
      turtle.abort = false
      releaseTicket(ticketId)
      os.queueEvent('turtle_response')
      if not s and m then
        printError(m)
      end
      return s, m
    end
  end
end

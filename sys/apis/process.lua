local Process = { }

function Process:init(args)
  self.args = { }
  self.uid = 0
  self.threads = { }
  Util.merge(self, args)
  self.name = self.name or 'Thread:' .. self.uid
end

function Process:isDead()
  return coroutine.status(self.co) == 'dead'
end

function Process:terminate()
  print('terminating ' .. self.name)
  self:resume('terminate')
end

function Process:threadEvent(...)

  for _,key in pairs(Util.keys(self.threads)) do
    local thread = self.threads[key]
    if thread then
      thread:resume(...)
    end
  end
end

function Process:addThread(fn, ...)
  return self:newThread(nil, fn, ...)
end

-- deprecated
function Process:newThread(name, fn, ...)

  self.uid = self.uid + 1

  local thread = { }
  setmetatable(thread, { __index = Process })
  thread:init({
    fn = fn,
    name = name,
    uid = self.uid,
  })

  local args = { ... }
  thread.co = coroutine.create(function()

    local s, m = pcall(function() fn(unpack(args)) end)
    if not s and m then
      if m == 'Terminated' then
        --printError(thread.name .. ' terminated')
      else
        printError(m)
      end
    end

--print('thread died ' .. thread.name)
    self.threads[thread.uid] = nil

    thread:threadEvent('terminate')

    return s, m
  end)

  self.threads[thread.uid] = thread

  thread:resume()

  return thread
end

function Process:resume(event, ...)

  -- threads get a chance to process the event regardless of the main process filter
  self:threadEvent(event, ...)

  if not self.filter or self.filter == event or event == "terminate" then
    local ok, result = coroutine.resume(self.co, event, ...)
    if ok then
      self.filter = result
    end
    return ok, result
  end

  return true, self.filter
end

function Process:pullEvent(filter)

  while true do
    local e = { os.pullEventRaw() }
    self:threadEvent(unpack(e))

    if not filter or e[1] == filter or e[1] == 'terminate' then
      return unpack(e)
    end
  end
end

function Process:pullEvents(filter)

  while true do
    local e = { os.pullEventRaw(filter) }
    self:threadEvent(unpack(e))
    if e[1] == 'terminate' then
      return unpack(e)
    end
  end
end

local process = { }
setmetatable(process, { __index = Process })
process:init({ name = 'Main', co = coroutine.running() })
return process

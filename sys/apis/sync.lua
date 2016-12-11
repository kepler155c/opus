local syncLocks = { }

return function(obj, fn)
  local key = tostring(obj)
  if syncLocks[key] then
    local cos = tostring(coroutine.running())
    table.insert(syncLocks[key], cos)
    repeat
      local _, co = os.pullEvent('sync_lock')
    until co == cos
  else
    syncLocks[key] = { }
  end
  local s, m = pcall(fn)
  local co = table.remove(syncLocks[key], 1)
  if co then
    os.queueEvent('sync_lock', co)
  else
    syncLocks[key] = nil
  end
  if not s then
    error(m)
  end
end

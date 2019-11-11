local Sync = {
	syncLocks = { }
}

local os = _G.os

function Sync.sync(obj, fn)
	local key = tostring(obj)
	if Sync.syncLocks[key] then
		local cos = tostring(coroutine.running())
		table.insert(Sync.syncLocks[key], cos)
		repeat
			local _, co = os.pullEvent('sync_lock')
		until co == cos
	else
		Sync.syncLocks[key] = { }
	end
	local s, m = pcall(fn)
	local co = table.remove(Sync.syncLocks[key], 1)
	if co then
		os.queueEvent('sync_lock', co)
	else
		Sync.syncLocks[key] = nil
	end
	if not s then
		error(m)
	end
end

function Sync.lock(obj)
	local key = tostring(obj)
	if Sync.syncLocks[key] then
		local cos = tostring(coroutine.running())
		table.insert(Sync.syncLocks[key], cos)
		repeat
			local _, co = os.pullEvent('sync_lock')
		until co == cos
	else
		Sync.syncLocks[key] = { }
	end
end

function Sync.release(obj)
	local key = tostring(obj)
	if not Sync.syncLocks[key] then
		error('Sync.release: Lock was not obtained', 2)
	end
	local co = table.remove(Sync.syncLocks[key], 1)
	if co then
		os.queueEvent('sync_lock', co)
	else
		Sync.syncLocks[key] = nil
	end
end

function Sync.isLocked(obj)
	local key = tostring(obj)
	return not not Sync.syncLocks[key]
end

return Sync

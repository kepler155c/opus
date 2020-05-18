local fs     = _G.fs
local os     = _G.os

fs.loadTab('sys/etc/fstab')

-- add some Lua compatibility functions
function os.remove(a)
	if fs.exists(a) then
        local s = pcall(fs.delete, a)
        return s and true or nil, a .. ': Unable to remove file'
	end
	return nil, a .. ': No such file or directory'
end

os.execute = function(cmd)
    if not cmd then
        return 1
    end

    local env = _G.getfenv(2)
    local s, m = env.shell.run('sys/apps/shell.lua ' .. cmd)

    if not s then
        return 1, m
    end

    return 0
end

os.tmpname = function()
    local fname
    repeat
        fname = 'tmp/a' .. math.random(1, 32768)
    until not fs.exists(fname)

    return fname
end

-- non-standard - will raise error instead
os.exit = function(code)
    error('Terminated with ' .. code)
end

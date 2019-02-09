local PASTEBIN_URL   = 'http://pastebin.com/raw'
local GIT_URL        = 'https://raw.githubusercontent.com'

local function split(str, pattern)
	local t = { }
	local function helper(line) table.insert(t, line) return "" end
	helper((str:gsub(pattern, helper)))
	return t
end

local luaPaths = package and package.path and split(package.path, '(.-);') or { }
for i = 1, #luaPaths do
	if luaPaths[i] == '?' or luaPaths[i] == '?.lua' then
		luaPaths[i] = nil
	end
end

table.insert(luaPaths, 1, '?.lua')
table.insert(luaPaths, 2, '?/init.lua')
table.insert(luaPaths, 3, '/usr/apis/?.lua')
table.insert(luaPaths, 4, '/usr/apis/?/init.lua')
table.insert(luaPaths, 5, '/sys/apis/?.lua')
table.insert(luaPaths, 6, '/sys/apis/?/init.lua')

local DEFAULT_PATH   = table.concat(luaPaths, ';')

local fs     = _G.fs
local http   = _G.http
local os     = _G.os
local string = _G.string

if not http._patched then
	-- fix broken http get (http.get is not coroutine safe)
	local syncLocks = { }

	local function sync(obj, fn)
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
		fn()
		local co = table.remove(syncLocks[key], 1)
		if co then
			os.queueEvent('sync_lock', co)
		else
			syncLocks[key] = nil
		end
	end

	-- todo -- completely replace http.get with function that
	-- checks for success on permanent redirects (minecraft 1.75 bug)

	http._patched = http.get
	function http.get(url, headers)
		local s, m
		sync(url, function()
			s, m = http._patched(url, headers)
		end)
		return s, m
	end
end

local function loadUrl(url)
	local c
	local h = http.get(url)
	if h then
		c = h.readAll()
		h.close()
	end
	if c and #c > 0 then
		return c
	end
end

-- Add require and package to the environment
return function(env)
	local function preloadSearcher(modname)
		if env.package.preload[modname] then
			return function()
				return env.package.preload[modname](modname, env)
			end
		end
	end

	local function loadedSearcher(modname)
			if env.package.loaded[modname] then
			return function()
				return env.package.loaded[modname]
			end
		end
	end

	local function pathSearcher(modname)
		local fname = modname:gsub('%.', '/')

		for pattern in string.gmatch(env.package.path, "[^;]+") do
			local sPath = string.gsub(pattern, "%?", fname)
			-- TODO: if there's no shell, we should not be checking relative paths below
			-- as they will resolve to root directory
			if sPath:match("^(https?:)") then
				local c = loadUrl(sPath)
				if c then
					return load(c, modname, nil, env)
				end
			else
				if env.shell and
					type(env.shell.getRunningProgram) == 'function' and
					sPath:sub(1, 1) ~= "/" then

					sPath = fs.combine(fs.getDir(env.shell.getRunningProgram() or ''), sPath)
				end
				if fs.exists(sPath) and not fs.isDir(sPath) then
					return loadfile(sPath, env)
				end
			end
		end
	end

	-- require('BniCQPVf')
	local function pastebinSearcher(modname)
		if #modname == 8 and not modname:match('%W') then
			local url = PASTEBIN_URL .. '/' .. modname
			local c = loadUrl(url)
			if c then
				return load(c, modname, nil, env)
			end
		end
	end

	-- require('kepler155c.opus.master.sys.apis.util')
	local function gitSearcher(modname)
		local fname = modname:gsub('%.', '/') .. '.lua'
		local _, count = fname:gsub("/", "")
		if count >= 3 then
			local url = GIT_URL .. '/' .. fname
			local c = loadUrl(url)
			if c then
				return load(c, modname, nil, env)
			end
		end
	end

	-- place package and require function into env
	env.package = {
		path   = env.LUA_PATH  or _G.LUA_PATH  or DEFAULT_PATH,
		config = '/\n:\n?\n!\n-',
		preload = { },
		loaded = {
			coroutine = coroutine,
			io     = io,
			math   = math,
			os     = os,
			string = string,
			table  = table,
		},
		loaders = {
			preloadSearcher,
			loadedSearcher,
			pathSearcher,
			pastebinSearcher,
			gitSearcher,
		}
	}

	function env.require(modname)
		for _,searcher in ipairs(env.package.loaders) do
			local fn, msg = searcher(modname)
			if fn then
				local module, msg2 = fn(modname, env)
				if not module then
					error(msg2 or (modname .. ' module returned nil'), 2)
				end
				env.package.loaded[modname] = module
				return module
			end
			if msg then
				error(msg, 2)
			end
		end
		error('Unable to find module ' .. modname)
	end

	return env.require -- backwards compatible
end

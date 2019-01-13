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

table.insert(luaPaths, 1, '?')
table.insert(luaPaths, 2, '?.lua')
table.insert(luaPaths, 3, '/usr/apis/?')
table.insert(luaPaths, 4, '/usr/apis/?.lua')
table.insert(luaPaths, 5, '/sys/apis/?')
table.insert(luaPaths, 6, '/sys/apis/?.lua')

local DEFAULT_PATH   = table.concat(luaPaths, ';')
local DEFAULT_BRANCH = _ENV.OPUS_BRANCH or _G.OPUS_BRANCH or 'develop-1.8'
local DEFAULT_UPATH  = GIT_URL .. '/kepler155c/opus/' .. DEFAULT_BRANCH .. '/sys/apis'

local fs     = _G.fs
local http   = _G.http
local os     = _G.os
local string = _G.string

if not http._patched then
	-- fix broken http get
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
	local function standardSearcher(modname)
		-- Should this be 2 diff searchers ? if yes, installer would need an update
		if env.package.preload[modname] then
			return function()
				return env.package.preload[modname](modname, env)
			end
		end
		if env.package.loaded[modname] then
			return function()
				return env.package.loaded[modname]
			end
		end
	end

	local function shellSearcher(modname)
		local fname = modname:gsub('%.', '/') .. '.lua'

		if env.shell and type(env.shell.getRunningProgram) == 'function' then
			local running = env.shell.getRunningProgram()
			if running then
				local path = fs.combine(fs.getDir(running), fname)
				if fs.exists(path) and not fs.isDir(path) then
					return loadfile(path, env)
				end
			end
		end
	end

	local function pathSearcher(modname)
		local fname = modname:gsub('%.', '/')

		for pattern in string.gmatch(env.package.path, "[^;]+") do
			local sPath = string.gsub(pattern, "%?", fname)
			if env.shell and env.shell.dir and sPath:sub(1, 1) ~= "/" then
				sPath = fs.combine(env.shell.dir(), sPath)
			end
			if fs.exists(sPath) and not fs.isDir(sPath) then
				return loadfile(sPath, env)
			end
		end
		--[[
		for dir in string.gmatch(env.package.path, "[^:]+") do
			local path = fs.combine(dir, fname)
			if fs.exists(path) and not fs.isDir(path) then
				return loadfile(path, env)
			end
		end
		]]
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

	local function urlSearcher(modname)
		local fname = modname:gsub('%.', '/') .. '.lua'

		if fname:sub(1, 1) ~= '/' then
			for entry in string.gmatch(env.package.upath, "[^;]+") do
				local url = entry .. '/' .. fname
				local c = loadUrl(url)
				if c then
					return load(c, modname, nil, env)
				end
			end
		end
	end

	-- place package and require function into env
	env.package = {
		path   = env.LUA_PATH  or _G.LUA_PATH  or DEFAULT_PATH,
		upath  = env.LUA_UPATH or _G.LUA_UPATH or DEFAULT_UPATH,
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
			standardSearcher,
			shellSearcher,
			pathSearcher,
			pastebinSearcher,
			gitSearcher,
			urlSearcher,
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

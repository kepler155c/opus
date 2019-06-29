local function split(str, pattern)
	local t = { }
	local function helper(line) table.insert(t, line) return "" end
	helper((str:gsub(pattern, helper)))
	return t
end

local hasMain
local luaPaths = package and package.path and split(package.path, '(.-);') or { }
for i = 1, #luaPaths do
	if luaPaths[i] == '?' or luaPaths[i] == '?.lua' or luaPaths[i] == '?/init.lua' then
		luaPaths[i] = nil
	elseif string.find(luaPaths[i], '/rom/modules/main') then
		hasMain = true
	end
end

table.insert(luaPaths, 1, '?.lua')
table.insert(luaPaths, 2, '?/init.lua')
table.insert(luaPaths, 3, '/usr/modules/?.lua')
table.insert(luaPaths, 4, '/usr/modules/?/init.lua')
if not hasMain then
	table.insert(luaPaths, 5, '/rom/modules/main/?')
	table.insert(luaPaths, 6, '/rom/modules/main/?.lua')
	table.insert(luaPaths, 7, '/rom/modules/main/?/init.lua')
end
table.insert(luaPaths, '/sys/modules/?.lua')
table.insert(luaPaths, '/sys/modules/?/init.lua')

local DEFAULT_PATH   = table.concat(luaPaths, ';')

local fs     = _G.fs
local os     = _G.os
local string = _G.string

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

	local sentinel = { }

	local function pathSearcher(modname)
		if env.package.loaded[modname] == sentinel then
			error("loop or previous error loading module '" .. modname .. "'", 0)
		end
		env.package.loaded[modname] = sentinel

		local fname = modname:gsub('%.', '/')

		for pattern in string.gmatch(env.package.path, "[^;]+") do
			local sPath = string.gsub(pattern, "%?", fname)
			-- TODO: if there's no shell, we should not be checking relative paths below
			-- as they will resolve to root directory
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
		error('Unable to find module ' .. modname, 2)
	end

	return env.require -- backwards compatible
end

-- https://www.lua.org/manual/5.1/manual.html#pdf-require
-- https://github.com/LuaDist/lua/blob/d2e7e7d4d43ff9068b279a617c5b2ca2c2771676/src/loadlib.c

local defaultPath = { }

do
	local function split(str)
		local t = { }
		local function helper(line) table.insert(t, line) return "" end
		helper((str:gsub('(.-);', helper)))
		return t
	end

	local function insert(p)
		for _,v in pairs(defaultPath) do
			if v == p then
				return
			end
		end
		table.insert(defaultPath, p)

	end

	local paths = '?.lua;?/init.lua;'
	paths = paths .. '/usr/modules/?.lua;/usr/modules/?/init.lua;'
	paths = paths .. '/rom/modules/main/?;/rom/modules/main/?.lua;/rom/modules/main/?/init.lua;'
	paths = paths .. '/sys/modules/?.lua;/sys/modules/?/init.lua'

	for _,v in pairs(split(paths)) do
		insert(v)
	end

	local luaPaths = package and package.path and split(package.path) or { }
	for _,v in pairs(luaPaths) do
		if v ~= '?' then
			insert(v)
		end
	end
end

local DEFAULT_PATH = table.concat(defaultPath, ';')

local fs     = _G.fs
local os     = _G.os
local string = _G.string

-- Add require and package to the environment
return function(env, programDir)
	local function preloadSearcher(modname)
		if env.package.preload[modname] then
			return function()
				return env.package.preload[modname](modname, env)
			end
		end
	end

	local function pathSearcher(modname)
		local fname = modname:gsub('%.', '/')

		for pattern in string.gmatch(env.package.path, "[^;]+") do
			local sPath = string.gsub(pattern, "%?", fname)

			if programDir and sPath:sub(1, 1) ~= "/" then
				sPath = fs.combine(programDir, sPath)
			end
			if fs.exists(sPath) and not fs.isDir(sPath) then
				return loadfile(fs.combine(sPath, ''), env)
			end
		end
	end

	-- place package and require function into env
	env.package = {
		path    = env.LUA_PATH or _G.LUA_PATH or DEFAULT_PATH,
		cpath   = '',
		config  = '/\n:\n?\n!\n-',
		preload = { },
		loaded  = {
			bit32 = bit32,
			coroutine = coroutine,
			_G     = env._G,
			io     = io,
			math   = math,
			os     = os,
			string = string,
			table  = table,
			debug  = debug,
			utf8   = utf8,
		},
		loaders = {
			preloadSearcher,
			pathSearcher,
		}
	}
	env.package.loaded.package = env.package

	local sentinel = { }

	function env.require(modname)
		if env.package.loaded[modname] then
			if env.package.loaded[modname] == sentinel then
				error("loop or previous error loading module '" .. modname .. "'", 0)
			end
			return env.package.loaded[modname]
		end

		local t = { }
		for _,searcher in ipairs(env.package.loaders) do
			local fn, msg = searcher(modname)
			if type(fn) == 'function' then
				env.package.loaded[modname] = sentinel

				local module = fn(modname, env) or true

				env.package.loaded[modname] = module
				return module
			end
			if msg then
				table.insert(t, msg)
			end
		end

		if #t > 0 then
			error(table.concat(t, '\n'), 2)
		end
		error('Unable to find module ' .. modname, 2)
	end
end

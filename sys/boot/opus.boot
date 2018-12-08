-- Loads the Opus environment regardless if the file system is local or not
local fs     = _G.fs
local http   = _G.http

_G.OPUS_BRANCH = 'master-1.8'
local GIT_REPO = 'kepler155c/opus/' .. _G.OPUS_BRANCH
local BASE     = 'https://raw.githubusercontent.com/' .. GIT_REPO

local sandboxEnv = setmetatable({ }, { __index = _G })
for k,v in pairs(_ENV) do
	sandboxEnv[k] = v
end

_G._debug = function() end

local function makeEnv()
	local env = setmetatable({ }, { __index = _G })
	for k,v in pairs(sandboxEnv) do
		env[k] = v
	end
	return env
end

local function run(file, ...)
	local s, m = loadfile(file, makeEnv())
	if s then
		return s(...)
	end
	error('Error loading ' .. file .. '\n' .. m)
end

local function runUrl(file, ...)
	local url = BASE .. '/' .. file

	local u = http.get(url)
	if u then
		local fn = load(u.readAll(), url, nil, makeEnv())
		u.close()
		if fn then
			return fn(...)
		end
	end
	error('Failed to download ' .. url)
end

-- Install require shim
if fs.exists('sys/apis/injector.lua') then
	_G.requireInjector = run('sys/apis/injector.lua')
else
	-- not local, run the file system directly from git
	_G.requireInjector = runUrl('sys/apis/injector.lua')
	runUrl('sys/extensions/2.vfs.lua')

	-- install file system
	fs.mount('', 'gitfs', GIT_REPO)
end

local s, m = pcall(run, 'sys/apps/shell', 'sys/kernel.lua', ...)

if not s then
	print('\nError loading Opus OS\n')
	_G.printError(m .. '\n')
end

if fs.restore then
	fs.restore()
end

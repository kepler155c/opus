_G.requireInjector(_ENV)

local Util = require('util')

local fs    = _G.fs
local shell = _ENV.shell

if not fs.exists('usr/apps') then
	fs.makeDir('usr/apps')
end
if not fs.exists('usr/autorun') then
	fs.makeDir('usr/autorun')
end
--if not fs.exists('usr/config/fstab') then
--	Util.writeFile('usr/config/fstab',
--		'usr gitfs kepler155c/opus-apps/' .. _G.OPUS_BRANCH)
--end

if not fs.exists('usr/config/shell') then
	Util.writeTable('usr/config/shell', {
		aliases  = shell.aliases(),
		path     = 'usr/apps:sys/apps:' .. shell.path(),
		lua_path = 'sys/apis:usr/apis',
	})
end

if not fs.exists('usr/config/packages') then
	local packages = {
		[ 'develop-1.8' ] = 'https://pastebin.com/raw/WhEiNGZE',
		[ 'master-1.8' ] = 'https://pastebin.com/raw/pexZpAxt',
	}

	if packages[_G.OPUS_BRANCH] then
		Util.download(packages[_G.OPUS_BRANCH], 'usr/config/packages')
	end
end

local config = Util.readTable('usr/config/shell')
if config.aliases then
	for k in pairs(shell.aliases()) do
		shell.clearAlias(k)
	end
	for k,v in pairs(config.aliases) do
		shell.setAlias(k, v)
	end
end
shell.setPath(config.path)
_G.LUA_PATH = config.lua_path

fs.loadTab('usr/config/fstab')

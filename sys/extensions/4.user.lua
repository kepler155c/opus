local Util = require('util')

local fs    = _G.fs
local shell = _ENV.shell

if not fs.exists('usr/apps') then
	fs.makeDir('usr/apps')
end
if not fs.exists('usr/autorun') then
	fs.makeDir('usr/autorun')
end

local lua_path = package.path

-- TODO: Temporary
local upgrade = Util.readTable('usr/config/shell')
if upgrade and not upgrade.upgraded then
	fs.delete('usr/config/shell')
end

if not fs.exists('usr/config/shell') then
	Util.writeTable('usr/config/shell', {
		aliases  = shell.aliases(),
		path     = 'usr/apps',
		lua_path = lua_path,
		upgraded = true,
	})
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

local path = config.path and Util.split(config.path, '(.-):') or { }
table.insert(path, 'sys/apps')
for _, v in pairs(Util.split(shell.path(), '(.-):')) do
	table.insert(path, v)
end

shell.setPath(table.concat(path, ':'))
_G.LUA_PATH = config.lua_path

fs.loadTab('usr/config/fstab')

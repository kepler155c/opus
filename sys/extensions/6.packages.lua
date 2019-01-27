local Packages = require('packages')
local Util     = require('util')

local fs    = _G.fs
local help  = _G.help
local shell = _ENV.shell

if not fs.exists('usr/config/packages') then
	Packages:downloadList()
end

local appPaths = Util.split(shell.path(), '(.-):')
local luaPaths = Util.split(_G.LUA_PATH, '(.-);')
local helpPaths = Util.split(help.path(), '(.-):')

table.insert(helpPaths, '/sys/help')

local function addEntry(t, e, n)
	for _,v in ipairs(t) do
		if v == e then
			return true
		end
	end
	table.insert(t, n or 1, e)
end

for name in pairs(Packages:installed()) do
	local packageDir = fs.combine('packages', name)
	if fs.exists(fs.combine(packageDir, '.install')) then
		local install = Util.readTable(fs.combine(packageDir, '.install'))
		if install and install.mount then
			fs.mount(table.unpack(Util.matches(install.mount)))
		end
	end

	addEntry(appPaths, packageDir)
	local apiPath = fs.combine(fs.combine('packages', name), 'apis')
	if fs.exists(apiPath) then
		fs.mount(fs.combine('sys/apis', name), 'linkfs', apiPath)
	end

	local helpPath = '/' .. fs.combine(fs.combine('packages', name), 'help')
	if fs.exists(helpPath) then
		table.insert(helpPaths, helpPath)
	end
end

help.setPath(table.concat(helpPaths, ':'))
shell.setPath(table.concat(appPaths, ':'))
_G.LUA_PATH = table.concat(luaPaths, ';')

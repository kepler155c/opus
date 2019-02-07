local Packages = require('packages')
local Util     = require('util')

local fs    = _G.fs
local help  = _G.help
local shell = _ENV.shell

if not fs.exists('usr/config/packages') then
	Packages:downloadList()
end

local appPaths = Util.split(shell.path(), '(.-):')
local helpPaths = Util.split(help.path(), '(.-):')

table.insert(helpPaths, '/sys/help')

for name in pairs(Packages:installed()) do
	local packageDir = fs.combine('packages', name)

	table.insert(appPaths, 1, packageDir)
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

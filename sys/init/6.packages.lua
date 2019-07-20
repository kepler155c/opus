local Packages = require('opus.packages')
local Util     = require('opus.util')

local fs    = _G.fs
local help  = _G.help
local shell = _ENV.shell

local appPaths = Util.split(shell.path(), '(.-):')
local helpPaths = Util.split(help.path(), '(.-):')

table.insert(helpPaths, '/sys/help')

for name in pairs(Packages:installed()) do
	local packageDir = fs.combine('packages', name)

	table.insert(appPaths, 1, '/' .. packageDir)
	local apiPath = fs.combine(packageDir, 'apis')
	if fs.exists(apiPath) then
		fs.mount(fs.combine('rom/modules/main', name), 'linkfs', apiPath)
	end

	local helpPath = '/' .. fs.combine(packageDir, 'help')
	if fs.exists(helpPath) then
		table.insert(helpPaths, helpPath)
	end

	local fstabPath = fs.combine(packageDir, 'etc/fstab')
	if fs.exists(fstabPath) then
		fs.loadTab(fstabPath)
	end
end

help.setPath(table.concat(helpPaths, ':'))
shell.setPath(table.concat(appPaths, ':'))

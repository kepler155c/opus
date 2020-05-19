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

	local fstabPath = fs.combine(packageDir, 'etc/fstab')
	if fs.exists(fstabPath) then
		fs.loadTab(fstabPath)
	end

	table.insert(appPaths, 1, '/' .. packageDir)

	local apiPath = fs.combine(packageDir, 'apis') -- TODO: rename dir to 'modules' (someday)
	if fs.exists(apiPath) then
		fs.mount(fs.combine('rom/modules/main', name), 'linkfs', apiPath)
	end

	local helpPath = '/' .. fs.combine(packageDir, 'help')
	if fs.exists(helpPath) then
		table.insert(helpPaths, helpPath)
	end
end

help.setPath(table.concat(helpPaths, ':'))
shell.setPath(table.concat(appPaths, ':'))

local function runDir(directory)
	local files = fs.list(directory)
	table.sort(files)

	for _,file in ipairs(files) do
		os.sleep(0)
		local result, err = shell.run(directory .. '/' .. file)
		if not result and err then
			_G.printError('\n' .. err)
		end
	end
end

for _, package in pairs(Packages:installedSorted()) do
	local packageDir = 'packages/' .. package.name .. '/init'
	if fs.exists(packageDir) and fs.isDir(packageDir) then
		runDir(packageDir)
	end
end

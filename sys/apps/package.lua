local BulkGet  = require('opus.bulkget')
local Config   = require('opus.config')
local Git      = require('opus.git')
local LZW      = require('opus.compress.lzw')
local Packages = require('opus.packages')
local Tar      = require('opus.compress.tar')
local Util     = require('opus.util')

local fs       = _G.fs
local term     = _G.term

local args     = { ... }
local action   = table.remove(args, 1)

local function makeSandbox()
	local sandbox = setmetatable(Util.shallowCopy(_ENV), { __index = _G })
	_G.requireInjector(sandbox)
	return sandbox
end

local function Syntax(msg)
	print('Syntax: package list | install [name] ... |  update [name] | updateall | uninstall [name]\n')
	error(msg)
end

local function progress(max)
	-- modified from: https://pastebin.com/W5ZkVYSi (apemanzilla)
	local _, y = term.getCursorPos()
	local wide, _ = term.getSize()
	term.setCursorPos(1, y)
	term.write("[")
	term.setCursorPos(wide - 6, y)
	term.write("]")
	local done = 0
	return function()
		done = done + 1
		local value = done / max
		term.setCursorPos(2,y)
		term.write(("="):rep(math.floor(value * (wide - 8))))
		local percent = math.floor(value * 100) .. "%"
		term.setCursorPos(wide - percent:len(),y)
		term.write(percent)
	end
end

local function runScript(script)
	if script then
		local s, m = pcall(function()
			local fn, m = load(script, 'script', nil, makeSandbox())
			if not fn then
				error(m)
			end
			fn()
		end)
		if not s and m then
			_G.printError(m)
		end
	end
end

local function install(name, isUpdate, ignoreDeps)
	local manifest = Packages:downloadManifest(name) or error('Invalid package')

	if not ignoreDeps then
		if manifest.required then
			for _, v in pairs(manifest.required) do
				if isUpdate or not Packages:isInstalled(v) then
					install(v, isUpdate)
				end
			end
		end
	end

	print(string.format('%s: %s',
		isUpdate and 'Updating' or 'Installing',
		name))

	local packageDir = fs.combine('packages', name)

	local list = Git.list(manifest.repository)
	-- clear out contents before install/update
	-- TODO: figure out whether to run
	-- install/uninstall for the package
	fs.delete(packageDir)

	local showProgress = progress(Util.size(list))

	local getList = { }
	for path, entry in pairs(list) do
		table.insert(getList, {
			path = fs.combine(packageDir, path),
			url = entry.url
		})
	end

	BulkGet.download(getList, function(_, s, m)
		if not s then
			error(m)
		end
		showProgress()
	end)

	if not isUpdate then
		runScript(manifest.install)
	end

	if Config.load('package').compression then
		local c = Tar.tar_string(packageDir)
		Util.writeFile(packageDir  .. '.tar.lzw', LZW.compress(c), 'wb')
		fs.delete(packageDir)
	end
end

if action == 'list' then
	for k in pairs(Packages:list()) do
		Util.print('[%s] %s', Packages:isInstalled(k) and 'x' or ' ', k)
	end
	return
end

if action == 'install' then
	local name = args[1] or Syntax('Invalid package')
	if Packages:isInstalled(name) then
		error('Package is already installed')
	end
	install(name)
	print('installation complete\n')
	_G.printError('Reboot is required')
	return
end

if action == 'refresh' then
	print('Downloading...')
	Packages:downloadList()
	print('refresh complete')
	return
end

if action == 'updateall' then
	for name in pairs(Packages:installed()) do
		install(name, true, true)
	end
	print('updateall complete')
	return
end

if action == 'update' then
	local name = args[1] or Syntax('Invalid package')
	if not Packages:isInstalled(name) then
		error('Package is not installed')
	end
	install(name, true)
	print('update complete')
	return
end

if action == 'uninstall' then
	local name = args[1] or Syntax('Invalid package')
	if not Packages:isInstalled(name) then
		error('Package is not installed')
	end

	local manifest = Packages:getManifest(name)
	runScript(manifest.uninstall)

	local packageDir = fs.combine('packages', name)
	fs.delete(packageDir)
	fs.delete(packageDir  .. '.tar.lzw')
	print('removed: ' .. packageDir)
	return
end

Syntax('Invalid command')

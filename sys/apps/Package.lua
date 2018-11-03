_G.requireInjector(_ENV)

local Packages = require('packages')
local Util     = require('util')

local fs = _G.fs

local args = { ... }
local action = table.remove(args, 1)

local function Syntax(msg)
	error(msg)
end

if action == 'list' then
	for k in pairs(Packages:list()) do
		Util.print('[%s] %s', Packages:isInstalled(k) and 'x' or ' ', k)
	end
end

if action == 'install' then
	local name = args[1] or Syntax('Invalid package')
	if Packages:isInstalled(name) then
		error('Package is already installed')
	end
	local manifest = Packages:getManifest(name) or error('Invalid package')
	local packageDir = 'packages/' .. name
	local method = args[2] or 'remote'
	if method == 'remote' then
		Util.writeTable(packageDir .. '/.install', {
			mount = string.format('%s gitfs %s', packageDir, manifest.repository),
		})
		Util.writeTable(fs.combine(packageDir, '.package'), manifest)
		print('success')
	end
end

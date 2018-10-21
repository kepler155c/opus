_G.requireInjector(_ENV)

local Util = require('util')

local fs = _G.fs

local PACKAGE_DIR = 'packages'

local Packages = { }

function Packages:installed()
	self.cache = { }

	if fs.exists(PACKAGE_DIR) then
		for _, dir in pairs(fs.list(PACKAGE_DIR)) do
			local path = fs.combine(fs.combine(PACKAGE_DIR, dir), '.package')
			self.cache[dir] = Util.readTable(path)
		end
	end

	return self.cache
end

function Packages:list()
	return Util.readTable('sys/packageList.lua') or { }
end

function Packages:isInstalled(package)
	return self:installed()[package]
end

return Packages

local Util = require('util')

local fs = _G.fs
local textutils = _G.textutils

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
	if self.packageList then
		return self.packageList
	end
	self.packageList = Util.readTable('sys/packageList.lua') or { }

	return self.packageList
end

function Packages:isInstalled(package)
	return self:installed()[package]
end

function Packages:getManifest(package)
	local fname = 'packages/' .. package .. '/.package'
	if fs.exists(fname) then
		return Util.readTable(fname)
	end
	local list = self:list()
	local url = list and list[package]

	if url then
		local c = Util.httpGet(url) -- will need to call load
		if c then
			return textutils.unserialize(c)
		end
	end
end

return Packages

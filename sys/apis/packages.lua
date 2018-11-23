local Util = require('util')

local fs        = _G.fs
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
	self.packageList = Util.readTable('usr/config/packages') or { }

	return self.packageList
end

function Packages:isInstalled(package)
	return self:installed()[package]
end

function Packages:getManifest(package)
	local fname = 'packages/' .. package .. '/.package'
	if fs.exists(fname) then
		local c = Util.readTable(fname)
		if c then
			c.repository = c.repository:gsub('{{OPUS_BRANCH}}', _G.OPUS_BRANCH)
			return c
		end
	end
	local list = self:list()
	local url = list and list[package]

	if url then
		local c = Util.httpGet(url)
		if c then
			c = textutils.unserialize(c)
			if c then
				c.repository = c.repository:gsub('{{OPUS_BRANCH}}', _G.OPUS_BRANCH)
				return c
			end
		end
	end
end

return Packages

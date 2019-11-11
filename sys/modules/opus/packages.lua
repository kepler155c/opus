local Util = require('opus.util')

local fs        = _G.fs
local textutils = _G.textutils

local PACKAGE_DIR = 'packages'

local Packages = { }

function Packages:installed()
	local list = { }

	if fs.exists(PACKAGE_DIR) then
		for _, dir in pairs(fs.list(PACKAGE_DIR)) do
			local path = fs.combine(fs.combine(PACKAGE_DIR, dir), '.package')
			list[dir] = Util.readTable(path)
		end
	end

	return list
end

function Packages:installedSorted()
	local list = { }

	for k, v in pairs(self.installed()) do
		v.name = k
		v.deps = { }
		table.insert(list, v)
		for _, v2 in pairs(v.required or { }) do
			v.deps[v2] = true
		end
	end

	table.sort(list, function(a, b)
		return not not (b.deps and b.deps[a.name])
	end)

	table.sort(list, function(a, b)
		return not (a.deps and a.deps[b.name])
	end)

	return list
end

function Packages:list()
	if not fs.exists('usr/config/packages') then
		self:downloadList()
	end
	return Util.readTable('usr/config/packages') or { }
end

function Packages:isInstalled(package)
	return self:installed()[package]
end

function Packages:downloadList()
	local packages = {
		[ 'develop-1.8' ] = 'https://raw.githubusercontent.com/kepler155c/opus-apps/develop-1.8/packages.list',
		[ 'master-1.8' ] = 'https://pastebin.com/raw/pexZpAxt',
	}

	if packages[_G.OPUS_BRANCH] then
		Util.download(packages[_G.OPUS_BRANCH], 'usr/config/packages')
	end
end

function Packages:downloadManifest(package)
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

function Packages:getManifest(package)
	local fname = 'packages/' .. package .. '/.package'
	if fs.exists(fname) then
		local c = Util.readTable(fname)
		if c and c.repository then
			c.repository = c.repository:gsub('{{OPUS_BRANCH}}', _G.OPUS_BRANCH)
			return c
		end
	end
	return self:downloadManifest(package)
end

return Packages

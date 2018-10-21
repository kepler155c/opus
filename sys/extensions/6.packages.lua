_G.requireInjector(_ENV)

local Packages = require('packages')
local Util     = require('util')

local shell = _ENV.shell
local fs = _G.fs

local appPaths = Util.split(shell.path(), '(.-):')
local luaPaths = Util.split(_G.LUA_PATH, '(.-):')

local function addPath(t, e)
	local function hasEntry()
		for _,v in ipairs(t) do
			if v == e then
				return true
			end
		end
	end
	if not hasEntry() then
		table.insert(t, 1, e)
	end
end

-- dependency graph
-- https://github.com/mpeterv/depgraph/blob/master/src/depgraph/init.lua

for name, package in pairs(Packages:installed()) do
	if  package.mount then
		fs.mount(table.unpack(Util.matches(package.mount)))
	end

	addPath(appPaths, fs.combine(fs.combine('packages', name), 'apps'))
	addPath(luaPaths, fs.combine(fs.combine('packages', name), 'apis'))
end

shell.setPath(table.concat(appPaths, ':'))
_G.LUA_PATH = table.concat(luaPaths, ':')

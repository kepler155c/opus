local Util = require('util')

local fs = _G.fs

local Config = { }

Config.load = function(fname, data)
	local filename = 'usr/config/' .. fname

	if not fs.exists('usr/config') then
	  fs.makeDir('usr/config')
	end

	if not fs.exists(filename) then
	  Util.writeTable(filename, data)
	else
	  Util.merge(data, Util.readTable(filename) or { })
	end
end

Config.update = function(fname, data)
	local filename = 'usr/config/' .. fname
	Util.writeTable(filename, data)
end

return Config
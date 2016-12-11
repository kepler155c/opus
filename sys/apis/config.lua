local Util = require('util')

local Config = { }

Config.load = function(fname, data)
	local filename = '/config/' .. fname

	if not fs.exists('/config') then
	  fs.makeDir('/config')
	end

	if not fs.exists(filename) then
	  Util.writeTable(filename, data)
	else
	  Util.merge(data, Util.readTable(filename) or { })
	end
end

Config.update = function(fname, data)
	local filename = '/config/' .. fname
	Util.writeTable(filename, data)
end

return Config
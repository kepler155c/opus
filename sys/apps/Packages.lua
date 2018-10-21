_G.requireInjector(_ENV)

local Packages = require('packages')
local Util     = require('util')

local args = { ... }

if args[1] == 'list' then
	for k,v in pairs(Packages:list()) do
		Util.print('[%s] %s', Packages:isInstalled(k) and 'x' or ' ', k)
	end
end


local LZW  = require('opus.compress.lzw')
local Tar  = require('opus.compress.tar')
local Util = require('opus.util')

local fs = _G.fs

if not fs.exists('packages') or not fs.isDir('packages') then
	return
end

for _, name in pairs(fs.list('packages')) do
	local fullName = fs.combine('packages', name)
	local packageName = name:match('(.+)%.tar%.lzw$')
	if packageName and not fs.isDir(fullName) then
		local dir = fs.combine('packages', packageName)
		if not fs.exists(dir) then
			local s, m = pcall(function()
				fs.mount(dir, 'ramfs', 'directory')

				local c = Util.readFile(fullName, 'rb')

				Tar.untar_string(LZW.decompress(c), dir)
			end)
			if not s then
				fs.delete(dir)
				print('failed to extract ' .. fullName)
				print(m)
			end
		end
	end
end

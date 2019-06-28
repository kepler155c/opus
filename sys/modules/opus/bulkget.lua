local Util = require('opus.util')

local parallel = _G.parallel

local BulkGet = { }

function BulkGet.download(list, callback)
	local t = { }
	local failed = false

	for _ = 1, 5 do
		table.insert(t, function()
			while true do
				local entry = table.remove(list)
				if not entry then
					break
				end
				local s, m = Util.download(entry.url, entry.path)
				if not s then
					failed = true
				end
				callback(entry, s, m)
				if failed then
					break
				end
			end
		end)
	end

	parallel.waitForAll(table.unpack(t))
end

return BulkGet

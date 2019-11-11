local Util = require('opus.util')

local History    = { }
local History_mt = { __index = History }

function History.load(filename, limit)

	local self = setmetatable({
		limit = limit,
		filename = filename,
	}, History_mt)

	self.entries = Util.readLines(filename) or { }
	self.pos = #self.entries + 1

	return self
end

function History:add(line)
	if line ~= self.entries[#self.entries] then
		table.insert(self.entries, line)
		if self.limit then
			while #self.entries > self.limit do
				table.remove(self.entries, 1)
			end
		end
		Util.writeLines(self.filename, self.entries)
		self.pos = #self.entries + 1
	end
end

function History:reset()
	self.pos = #self.entries + 1
end

function History:back()
	if self.pos > 1 then
		self.pos = self.pos - 1
		return self.entries[self.pos]
	end
end

function History:forward()
	if self.pos <= #self.entries then
		self.pos = self.pos + 1
		return self.entries[self.pos]
	end
end

return History

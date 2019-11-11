local git = require('opus.git')

local fs = _G.fs

local gitfs = { }

function gitfs.mount(dir, repo)
	if not repo then
		error('gitfs syntax: repo')
	end

	local list = git.list(repo)
	for path, entry in pairs(list) do
		if not fs.exists(fs.combine(dir, path)) then
			local node = fs.mount(fs.combine(dir, path), 'urlfs', entry.url)
			node.size = entry.size
		end
	end
end

return gitfs

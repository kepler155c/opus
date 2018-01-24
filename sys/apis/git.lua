local json = require('json')
local Util = require('util')

local TREE_URL = 'https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1'
local FILE_URL = 'https://raw.githubusercontent.com/%s/%s/%s/%s'

local git = { }

function git.list(repository)

	local t = Util.split(repository, '(.-)/')

	local user = t[1]
	local repo = t[2]
	local branch = t[3] or 'master'

	local dataUrl = string.format(TREE_URL, user, repo, branch)
	local contents = Util.download(dataUrl)

	if not contents then
		error('Invalid repository')
	end

	local data = json.decode(contents)

	if data.message and data.message:find("API rate limit exceeded") then
		error("Out of API calls, try again later")
	end

	if data.message and data.message == "Not found" then
		error("Invalid repository")
	end

	local list = { }

	for _,v in pairs(data.tree) do
		if v.type == "blob" then
			v.path = v.path:gsub("%s","%%20")
			list[v.path] = {
				url = string.format(FILE_URL, user, repo, branch, v.path),
				size = v.size,
			}
		end
	end

	return list
end

return git

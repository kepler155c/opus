local json = require('opus.json')
local Util = require('opus.util')

local TREE_URL = 'https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1'
local FILE_URL = 'https://raw.githubusercontent.com/%s/%s/%s/%s'
local TREE_HEADERS = {}
local git = { }

if _G._GIT_API_KEY then
	TREE_HEADERS.Authorization =  'token ' .. _G._GIT_API_KEY
end

function git.list(repository)
	local t = Util.split(repository, '(.-)/')

	local user = table.remove(t, 1)
	local repo = table.remove(t, 1)
	local branch = table.remove(t, 1) or 'master'
	local path

	if not Util.empty(t) then
		path = table.concat(t, '/') .. '/'
	end

	local function getContents()
		local dataUrl = string.format(TREE_URL, user, repo, branch)
		local contents, msg = Util.httpGet(dataUrl, TREE_HEADERS)
		if not contents then
			error(string.format('Failed to download %s\n%s', dataUrl, msg), 2)
		else
			return json.decode(contents)
		end
	end

	local data = getContents() or error('Invalid repository')

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
			if not path then
				list[v.path] = {
					url = string.format(FILE_URL, user, repo, branch, v.path),
					size = v.size,
				}
			elseif Util.startsWith(v.path, path) then
				local p = string.sub(v.path, #path)
				list[p] = {
					url = string.format(FILE_URL, user, repo, branch, path .. p),
					size = v.size,
				}
			end
		end
	end

	return list
end

return git

local json = require('json')

local TREE_URL = 'https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1'
local FILE_URL = 'https://raw.github.com/%s/%s/%s/%s'

local git = { }

function git.list(user, repo, branch)
  branch = branch or 'master'

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

  for k,v in pairs(data.tree) do
    if v.type == "blob" then
      v.path = v.path:gsub("%s","%%20")
      list[v.path] = string.format(FILE_URL, user, repo, branch, v.path)
    end
  end

  return list
end

return git

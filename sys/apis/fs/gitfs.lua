local git = require('git')

local gitfs = { }

function gitfs.mount(dir, user, repo, branch)
  if not user or not repo then
    error('gitfs syntax: user, repo, [branch]')
  end

  local list = git.list(user, repo, branch)
  for path, entry in pairs(list) do
    local node = fs.mount(fs.combine(dir, path), 'urlfs', entry.url)
    node.size = entry.size
  end
end

return gitfs

local git = require('git')

local gitfs = { }

function gitfs.mount(dir, user, repo, branch)
  if not user or not repo then
    error('gitfs syntax: user, repo, [branch]')
  end

  local list = git.list(user, repo, branch)
  for path, url in pairs(list) do
    fs.mount(fs.combine(dir, path), 'urlfs', url)
  end
end

return gitfs

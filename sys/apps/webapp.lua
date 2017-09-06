local args = { ... }
local GIT_USER = 'kepler155c'
local GIT_REPO = 'opus'
local GIT_BRANCH = 'develop'
local BASE = 'https://raw.githubusercontent.com/kepler155c/opus/develop/'

local function dourl(env, url)
  local h = http.get(url)
  if h then
    local fn, m = load(h.readAll(), url, nil, env)
    h.close()
    if fn then
      return fn()
    end
  end
  error('Failed to download ' .. url)
end

local s, m = pcall(function()

  _G.requireInjector = dourl(getfenv(1), BASE .. 'sys/apis/injector.lua')

  local function mkenv()
    local env = { }
    for k,v in pairs(getfenv(1)) do
      env[k] = v 
    end
    setmetatable(env, { __index = _G })
    return env
  end

  -- install vfs
  dourl(mkenv(), BASE .. 'sys/extensions/vfs.lua')

  -- install filesystem
  fs.mount('',       'gitfs', GIT_USER, GIT_REPO, GIT_BRANCH)

  -- start program
  local file = table.remove(args, 1)

  local s, m = os.run(mkenv(), file or 'startup', unpack(args))
  if not s and m then
    error(m)
  end
end)

if not s and m then
  printError(m)
end

if fs.restore then
  fs.restore()
end

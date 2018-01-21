local PASTEBIN_URL  = 'http://pastebin.com/raw'
local GIT_URL       = 'https://raw.githubusercontent.com'
local DEFAULT_PATH  = 'sys/apis'
local DEFAULT_UPATH = GIT_URL .. '/kepler155c/opus/' .. _ENV.BRANCH .. '/sys/apis'

local fs   = _G.fs
local http = _G.http
local os   = _G.os

if not http._patched then
  -- fix broken http get
  local syncLocks = { }

  local function sync(obj, fn)
    local key = tostring(obj)
    if syncLocks[key] then
      local cos = tostring(coroutine.running())
      table.insert(syncLocks[key], cos)
      repeat
        local _, co = os.pullEvent('sync_lock')
      until co == cos
    else
      syncLocks[key] = { }
    end
    fn()
    local co = table.remove(syncLocks[key], 1)
    if co then
      os.queueEvent('sync_lock', co)
    else
      syncLocks[key] = nil
    end
  end

  -- todo -- completely replace http.get with function that
  -- checks for success on permanent redirects (minecraft 1.75 bug)

  http._patched = http.get
  function http.get(url, headers)
    local s, m
    sync(url, function()
      s, m = http._patched(url, headers)
    end)
    return s, m
  end
end

local function loadUrl(url)
  local c
  local h = http.get(url)
  if h then
    c = h.readAll()
    h.close()
  end
  if c and #c > 0 then
    return c
  end
end

-- Add require and package to the environment
local function requireWrapper(env)

  local function standardSearcher(modname)
    if env.package.loaded[modname] then
      return function()
        return env.package.loaded[modname]
      end
    end
  end

  local function shellSearcher(modname)
    local fname = modname:gsub('%.', '/') .. '.lua'

    if env.shell and type(env.shell.dir) == 'function' then
      local path = env.shell.resolve(fname)
      if fs.exists(path) and not fs.isDir(path) then
        return loadfile(path, env)
      end
    end
  end

  local function pathSearcher(modname)
    local fname = modname:gsub('%.', '/') .. '.lua'

    for dir in string.gmatch(env.package.path, "[^:]+") do
      local path = fs.combine(dir, fname)
      if fs.exists(path) and not fs.isDir(path) then
        return loadfile(path, env)
      end
    end
  end

  -- require('BniCQPVf')
  local function pastebinSearcher(modname)
    if #modname == 8 and not modname:match('%W') then
      local url = PASTEBIN_URL .. '/' .. modname
      local c = loadUrl(url)
      if c then
        return load(c, modname, nil, env)
      end
    end
  end

  -- require('kepler155c.opus.master.sys.apis.util')
  local function gitSearcher(modname)
    local fname = modname:gsub('%.', '/') .. '.lua'
    local _, count = fname:gsub("/", "")
    if count >= 3 then
      local url = GIT_URL .. '/' .. fname
      local c = loadUrl(url)
      if c then
        return load(c, modname, nil, env)
      end
    end
  end

  local function urlSearcher(modname)
    local fname = modname:gsub('%.', '/') .. '.lua'

    if fname:sub(1, 1) ~= '/' then
      for entry in string.gmatch(env.package.upath, "[^;]+") do
        local url = entry .. '/' .. fname
        local c = loadUrl(url)
        if c then
          return load(c, modname, nil, env)
        end
      end
    end
  end

  -- place package and require function into env
  env.package = {
    path   = env.LUA_PATH  or os.getenv('LUA_PATH')  or DEFAULT_PATH,
    upath  = env.LUA_UPATH or os.getenv('LUA_UPATH') or DEFAULT_UPATH,
    config = '/\n:\n?\n!\n-',
    loaded = {
      math   = math,
      string = string,
      table  = table,
      io     = io,
      os     = os,
    },
    loaders = {
      standardSearcher,
      shellSearcher,
      pathSearcher,
      pastebinSearcher,
      gitSearcher,
      urlSearcher,
    }
  }

  function env.require(modname)
    for _,searcher in ipairs(env.package.loaders) do
      local fn, msg = searcher(modname)
      if fn then
        local module, msg2 = fn(modname, env)
        if not module then
          error(msg2 or (modname .. ' module returned nil'), 2)
        end
        env.package.loaded[modname] = module
        return module
      end
      if msg then
        error(msg, 2)
      end
    end
    error('Unable to find module ' .. modname)
  end

  return env.require -- backwards compatible
end

return function(env)
  env = env or getfenv(2)
  --setfenv(requireWrapper, env)
  return requireWrapper(env)
end

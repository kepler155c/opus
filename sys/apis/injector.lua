local branch = 'master'
if fs.exists('.branch') then
  local f = fs.open('.branch', "r")
  if f then
    branch = f.readAll()
    f.close()
  end
end

local DEFAULT_UPATH = 'https://raw.githubusercontent.com/kepler155c/opus/' .. branch .. '/sys/apis'
local PASTEBIN_URL  = 'http://pastebin.com/raw'
local GIT_URL       = 'https://raw.githubusercontent.com'

local function standardSearcher(modname, env, shell)
  if package.loaded[modname] then
    return function()
      return package.loaded[modname]
    end
  end
end

local function shellSearcher(modname, env, shell)
  local fname = modname:gsub('%.', '/') .. '.lua'

  if shell and type(shell.dir) == 'function' then
    local path = shell.resolve(fname)
    if fs.exists(path) and not fs.isDir(path) then
      return loadfile(path, env)
    end
  end
end

local function pathSearcher(modname, env, shell)
  local fname = modname:gsub('%.', '/') .. '.lua'

  for dir in string.gmatch(package.path, "[^:]+") do
    local path = fs.combine(dir, fname)
    if fs.exists(path) and not fs.isDir(path) then
      return loadfile(path, env)
    end
  end
end

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
  local s, m = pcall(fn)
  local co = table.remove(syncLocks[key], 1)
  if co then
    os.queueEvent('sync_lock', co)
  else
    syncLocks[key] = nil
  end
  if not s then
    error(m)
  end
end

local function loadUrl(url)
  local c
  sync(url, function()
    local h = http.get(url)
    if h then
      c = h.readAll()
      h.close()
    end
  end)
  if c and #c > 0 then
    return c
  end
end

-- require('BniCQPVf')
local function pastebinSearcher(modname, env, shell)
  if #modname == 8 and not modname:match('%W') then
    local url = PASTEBIN_URL .. '/' .. modname
    local c = loadUrl(url)
    if c then
      return load(c, modname, nil, env)
    end
  end
end

-- require('kepler155c.opus.master.sys.apis.util')
local function gitSearcher(modname, env, shell)
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

local function urlSearcher(modname, env, shell)
  local fname = modname:gsub('%.', '/') .. '.lua'

  if fname:sub(1, 1) ~= '/' then
    for entry in string.gmatch(package.upath, "[^;]+") do
      local url = entry .. '/' .. fname
      local c = loadUrl(url)
      if c then
        return load(c, modname, nil, env)
      end
    end
  end
end

_G.package = {
  path = LUA_PATH or 'sys/apis',
  upath = LUA_UPATH or DEFAULT_UPATH,
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

local function requireWrapper(env)

  local loaded = { }

  return function(modname)

    if loaded[modname] then
      return loaded[modname]
    end

    for _,searcher in ipairs(package.loaders) do
      local fn, msg = searcher(modname, env, shell)
      if fn then
        local module, msg = fn(modname, env)
        if not module then
          error(msg)
        end
        loaded[modname] = module
        return module
      end
      if msg then
        error(msg, 2)
      end
    end
    error('Unable to find module ' .. modname)
  end
end

return function(env)
  setfenv(requireWrapper, env)
  return requireWrapper(env)
end

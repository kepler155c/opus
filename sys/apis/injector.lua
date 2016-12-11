local resolver, loader

local function resolveFile(filename, dir, lua_path)

  if filename:sub(1, 1) == "/" then
    if not fs.exists(filename) then
      error('Unable to load: ' .. filename, 2)
    end
    return filename
  end

  if dir then
    local path = fs.combine(dir, filename)
    if fs.exists(path) and not fs.isDir(path) then
      return path
    end
  end

  if lua_path then
    for dir in string.gmatch(lua_path, "[^:]+") do
      local path = fs.combine(dir, filename)
      if fs.exists(path) and not fs.isDir(path) then
        return path
      end
    end
  end

  error('Unable to load: ' .. filename, 2)
end

local function requireWrapper(env)

  local modules = { }

  return function(filename)

    local dir = DIR
    if not dir and shell and type(shell.dir) == 'function' then
      dir = shell.dir()
    end

    local fname = resolver(filename:gsub('%.', '/') .. '.lua',
      dir or '', LUA_PATH or '/sys/apis')

    local rname = fname:gsub('%/', '.'):gsub('%.lua', '')

    local module = modules[rname]
    if not module then

      local f, err = loader(fname, env)
      if not f then
        error(err)
      end 
      module = f(rname)
      modules[rname] = module
    end

    return module
  end
end

local args = { ... }
resolver = args[1] or resolveFile
loader   = args[2] or loadfile

return function(env)
  setfenv(requireWrapper, env)
  return requireWrapper(env)
end

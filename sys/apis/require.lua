local function resolveFile(filename, dir, lua_path)

  local ch = string.sub(filename, 1, 1)
  if ch == "/" then
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
end

local modules = { }

return function(filename)

  local dir = DIR
  if not dir and shell and type(shell.dir) == 'function' then
    dir = shell.dir()
  end

  local fname = resolveFile(filename:gsub('%.', '/') .. '.lua',
    dir or '', LUA_PATH or '/sys/apis')

  if not fname or not fs.exists(fname) then
    error('Unable to load: ' .. filename, 2)
  end

  local rname = fname:gsub('%/', '.'):gsub('%.lua', '')

  local module = modules[rname]
  if not module then

    local f, err = loadfile(fname)
    if not f then
      error(err)
    end 
    setfenv(f, getfenv(1))

    module = f(rname)

    modules[rname] = module
  end

  return module
end

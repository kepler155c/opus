local sandboxEnv = setmetatable({ }, { __index = _G })
for k,v in pairs(_ENV) do
  sandboxEnv[k] = v
end

_G.requireInjector()

local Util = require('util')

_G.kernel = {
  hooks = { }
}

local kernel = _G.kernel
local fs     = _G.fs
local shell  = _ENV.shell

-- user environment
if not fs.exists('usr/apps') then
  fs.makeDir('usr/apps')
end
if not fs.exists('usr/autorun') then
  fs.makeDir('usr/autorun')
end
if not fs.exists('usr/etc/fstab') then
  Util.writeFile('usr/etc/fstab', 'usr gitfs kepler155c/opus-apps/develop')
end
if not fs.exists('usr/config/shell') then
  Util.writeTable('usr/config/shell', {
    aliases  = shell.aliases(),
    path     = 'usr/apps:sys/apps:' .. shell.path(),
    lua_path = '/sys/apis:/usr/apis',
  })
end

-- shell environment
local config = Util.readTable('usr/config/shell')
if config.aliases then
  for k in pairs(shell.aliases()) do
    shell.clearAlias(k)
  end
  for k,v in pairs(config.aliases) do
    shell.setAlias(k, v)
  end
end
shell.setPath(config.path)
_G.LUA_PATH = config.lua_path

-- any function that runs in a kernel hook does not run in
-- a separate coroutine or have a window. an error in a hook
-- function will crash the system.
function kernel.hook(event, fn)
  if type(event) == 'table' then
    for _,v in pairs(event) do
      kernel.hook(v, fn)
    end
  else
    if not kernel.hooks[event] then
      kernel.hooks[event] = { }
    end
    table.insert(kernel.hooks[event], fn)
  end
end

-- you can only unhook from within the function that hooked
function kernel.unhook(event, fn)
  local eventHooks = kernel.hooks[event]
  if eventHooks then
    Util.removeByValue(eventHooks, fn)
    if #eventHooks == 0 then
      kernel.hooks[event] = nil
    end
  end
end

-- extensions
local dir = 'sys/extensions'
for _,file in ipairs(fs.list(dir)) do
  local s, m = Util.run(sandboxEnv, 'sys/apps/shell', fs.combine(dir, file))
  if not s then
    error(m)
  end
end

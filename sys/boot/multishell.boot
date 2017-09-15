print('\nStarting Opus..')

LUA_PATH = '/sys/apis:/usr/apis'

local Util = dofile('sys/apis/util.lua')
_G.debug = function(...) Util.print(...) end
_G.requireInjector = dofile('sys/apis/injector.lua')

os.run(Util.shallowCopy(getfenv(1)), 'sys/extensions/device.lua')

-- vfs
local s, m = os.run(Util.shallowCopy(getfenv(1)), 'sys/extensions/vfs.lua')
if not s then
  error(m)
end

-- process fstab
local mounts = Util.readFile('usr/etc/fstab')
if mounts then
  for _,l in ipairs(Util.split(mounts)) do
    if l:sub(1, 1) ~= '#' then
      print('mounting ' .. l)
      fs.mount(unpack(Util.matches(l)))
    end
  end
end

fs.mount('usr', 'gitfs', 'kepler155c', 'opus-apps', 'develop')

-- user environment
if not fs.exists('usr/apps') then
  fs.makeDir('usr/apps')
end
if not fs.exists('usr/autorun') then
  fs.makeDir('usr/autorun')
end

local env = Util.shallowCopy(getfenv(1))
env.multishell = { }

local _, m = os.run(env, 'sys/apps/shell', 'sys/apps/multishell')
printError(m or 'Multishell aborted')

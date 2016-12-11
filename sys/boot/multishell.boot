print('\nStarting multishell..')

LUA_PATH = '/sys/apis'

math.randomseed(os.clock())

_G.debug = function() end
_G.Util = dofile('/sys/apis/util.lua')
_G.requireInjector = dofile('/sys/apis/injector.lua')

os.run(Util.shallowCopy(getfenv(1)), '/sys/extensions/device.lua')

-- vfs
local s, m = os.run(Util.shallowCopy(getfenv(1)), '/sys/extensions/vfs.lua')
if not s then
  error(m)
end

-- process fstab
local mounts = Util.readFile('config/fstab')
if mounts then
  for _,l in ipairs(Util.split(mounts)) do
    if l:sub(1, 1) ~= '#' then
      fs.mount(unpack(Util.matches(l)))
    end
  end
end

local env = Util.shallowCopy(getfenv(1))
env.multishell = { }

local _, m = os.run(env, '/apps/shell', '/apps/multishell')
printError(m or 'Multishell aborted')

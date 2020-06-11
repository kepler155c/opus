local Util = require('opus.util')

-- some programs expect to be run in the global scope
-- ie. busted, moonscript

-- create a new environment mimicing pure lua

local fs    = _G.fs
local shell = _ENV.shell

local env = Util.shallowCopy(_G)
Util.merge(env, _ENV)
env._G = env

env.arg = { ... }
env.arg[0] = shell.resolveProgram(table.remove(env.arg, 1) or error('file name is required'))

_G.requireInjector(env, fs.getDir(env.arg[0]))

local s, m = Util.run(env, env.arg[0], table.unpack(env.arg))

if not s then
    error(m, -1)
end

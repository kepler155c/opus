print('\nStarting Opus..')

local function run(file, ...)
  local env = setmetatable({
    LUA_PATH = '/sys/apis:/usr/apis'
  }, { __index = _G })
  for k,v in pairs(getfenv(1)) do
    env[k] = v 
  end

  local s, m = loadfile(file, env)
  if s then
    local args = { ... }
    s, m = pcall(function()
      return s(table.unpack(args))
    end)
  end

  if not s then
    printError('Error loading ' .. file)
    error(m)
  end
  return m
end

_G.requireInjector = run('sys/apis/injector.lua')

-- user environment
if not fs.exists('usr/apps') then
  fs.makeDir('usr/apps')
end
if not fs.exists('usr/autorun') then
  fs.makeDir('usr/autorun')
end
if not fs.exists('usr/etc/fstab') then
  local file = io.open('usr/etc/fstab', "w")
  file:write('usr gitfs kepler155c/opus-apps/master')
  file:close()
end

local dir = 'sys/extensions'
for _,file in ipairs(fs.list(dir)) do
  run('sys/apps/shell', fs.combine(dir, file))
end

fs.loadTab('usr/etc/fstab')

local args = { ... }
args[1] = args[1] or 'sys/apps/multishell'

run('sys/apps/shell', table.unpack(args))

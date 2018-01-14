-- Loads the Opus environment regardless if the file system is local or not
local colors = _G.colors
local fs     = _G.fs
local http   = _G.http
local os     = _G.os
local term   = _G.term
local window = _G.window

local BRANCH   = 'develop-1.8'
local GIT_REPO = 'kepler155c/opus/' .. BRANCH
local BASE     = 'https://raw.githubusercontent.com/' .. GIT_REPO

local sandboxEnv = setmetatable({ }, { __index = _G })
for k,v in pairs(_ENV) do
  sandboxEnv[k] = v
end
sandboxEnv.multishell = { }
sandboxEnv.BRANCH = BRANCH
sandboxEnv.LUA_PATH = 'sys/apis:usr/apis'

_G.debug = function() end

local terminal = term.current()
local w, h = term.getSize()
local kernelWindow = window.create(terminal, 1, 1, w, h, false)
term.redirect(kernelWindow)
kernelWindow.parent = terminal
local splashWindow

local function showStatus(status, ...)
  local str = string.format(status, ...)
  print(str)
  splashWindow.setCursorPos(1, h)
  splashWindow.clearLine()
  splashWindow.setCursorPos((w - #str) / 2, h)
  splashWindow.write(str)
  os.sleep(.1)
end

local function splash()
  splashWindow = window.create(terminal, 1, 1, w, h, false)
  splashWindow.setTextColor(colors.white)
  if splashWindow.isColor() then
    splashWindow.setBackgroundColor(colors.black)
    splashWindow.clear()
    local opus = {
      'fffff00',
      'ffff07000',
      'ff00770b00 4444',
      'ff077777444444444',
      'f07777744444444444',
      'f0000777444444444',
      '070000111744444',
      '777770000',
      '7777000000',
      '70700000000',
      '077000000000',
    }
    for k,line in ipairs(opus) do
      splashWindow.setCursorPos((w - 18) / 2, k + (h - #opus) / 2)
      splashWindow.blit(string.rep(' ', #line), string.rep('a', #line), line)
    end
  end
  splashWindow.setVisible(true)
  return splashWindow
end

local function makeEnv()
  local env = setmetatable({ }, { __index = _G })
  for k,v in pairs(sandboxEnv) do
    env[k] = v
  end
  return env
end

local function run(file, ...)
  local s, m = loadfile(file, makeEnv())
  if s then
    s, m = pcall(s, ...)
    if s then
      return m
    end
  end
  error('Error loading ' .. file .. '\n' .. m)
end

local function runUrl(file, ...)
  local url = BASE .. '/' .. file

  local u = http.get(url)
  if u then
    local fn = load(u.readAll(), url, nil, makeEnv())
    u.close()
    if fn then
      return fn(...)
    end
  end
  error('Failed to download ' .. url)
end


local args = { ... }

splash()
local s, m = pcall(function()
  showStatus('Loading Opus OS...')

  -- Install require shim
  if fs.exists('sys/apis/injector.lua') then
    _G.requireInjector = run('sys/apis/injector.lua')
  else
    -- not local, run the file system directly from git
    _G.requireInjector = runUrl('sys/apis/injector.lua')
    runUrl('sys/extensions/2.vfs.lua')

    -- install file system
    fs.mount('', 'gitfs', GIT_REPO)
  end

  showStatus('Starting kernel')
  run('sys/apps/shell', 'sys/kernel.lua', args[1] and 6 or 7)

  if args[1] then
    local s, m = kernel.run({
      title = 'startup',
      path = 'sys/apps/shell',
      args = args,
      haltOnExit = true,
    })
    if s then
      kernel.raise(s.uid)
    else
      error(m)
    end
  end

  splashWindow.setVisible(false)
  kernelWindow.setVisible(true)
  _G.kernel.start()
end)

if not s then
  splashWindow.setVisible(false)
  kernelWindow.setVisible(true)
  print('\nError loading Opus OS\n')
  _G.printError(m .. '\n')
  term.redirect(terminal)
end

if fs.restore then
  fs.restore()
end

-- Loads the Opus environment regardless if the file system is local or not
local colors = _G.colors
local fs     = _G.fs
local http   = _G.http
local os     = _G.os
local shell  = _ENV.shell
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

local function setLabel()
  -- Default label
  if not os.getComputerLabel() then
    showStatus('Setting computer label')

    local id = os.getComputerID()
    if _G.turtle then
      os.setComputerLabel('turtle_' .. id)
    elseif _G.pocket then
      os.setComputerLabel('pocket_' .. id)
    elseif _G.commands then
      os.setComputerLabel('command_' .. id)
    else
      os.setComputerLabel('computer_' .. id)
    end
  end
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

local function createUserEnvironment(Util)
  showStatus('Creating user environment')

  if not fs.exists('usr/apps') then
    fs.makeDir('usr/apps')
  end
  if not fs.exists('usr/autorun') then
    fs.makeDir('usr/autorun')
  end
  if not fs.exists('usr/etc/fstab') then
    Util.writeFile('usr/etc/fstab', 'usr gitfs kepler155c/opus-apps/' .. BRANCH)
  end
end

local function createShellEnvironment(Util)
  showStatus('Creating shell environment')

  if not fs.exists('usr/config/shell') then
    Util.writeTable('usr/config/shell', {
      aliases  = shell.aliases(),
      path     = 'usr/apps:sys/apps:' .. shell.path(),
      lua_path = '/sys/apis:/usr/apis',
    })
  end

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
  sandboxEnv.LUA_PATH = config.lua_path
end

local function loadExtensions()
  local dir = 'sys/extensions'
  local files = fs.list(dir)
  table.sort(files)
  for _,file in ipairs(files) do
    showStatus('Loading ' .. file)
    local s, m = kernel.run({
      title = file:match('%d.(%S+).lua'),
      hidden = true,
      path = 'sys/apps/shell',
      args = { fs.combine(dir, file) },
      terminal = kernelWindow,
    })
    if not s then
      error(m)
    end
  end
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
    runUrl('sys/extensions/vfs.lua')

    -- install file system
    fs.mount('', 'gitfs', GIT_REPO)
  end

  _G.requireInjector()
  local Util = require('util')

  setLabel()
  createUserEnvironment(Util)
  createShellEnvironment(Util)

  showStatus('Reticulating splines')
  Util.run(makeEnv(), 'sys/kernel.lua')

  loadExtensions()

  showStatus('Mounting file systems')
  fs.loadTab('usr/etc/fstab')

  splashWindow.setVisible(false)
  if args[1] then
    kernelWindow.setVisible(true)
    kernelWindow.setVisible(false)
  end

  term.redirect(terminal)

  _G.kernel.run({
    path = 'sys/apps/shell',
    args = args[1] and args or { 'sys/apps/multishell' },
  })
end)

if not s then
  splashWindow.setVisible(false)
  kernelWindow.setVisible(true)
  print('\nError loading Opus OS\n')
  _G.printError(m .. '\n')
else
  if _G.kernel.routines[1] then
    _G.kernel.start()
  end
end

if fs.restore then
  fs.restore()
end

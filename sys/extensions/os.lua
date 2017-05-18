require = requireInjector(getfenv(1))
local Config = require('config')

local config = {
  enable = false,
  pocketId = 10,
  distance = 8,
}

local lockId

function lockScreen()
  require = requireInjector(getfenv(1))
  local UI = require('ui')
  local Event = require('event')
  local SHA1 = require('sha1')

  local center = math.floor(UI.term.width / 2)

  local page = UI.Page({
    backgroundColor = colors.blue,
    prompt = UI.Text({
      x = center - 9,
      y = math.floor(UI.term.height / 2),
      value = 'Password',
    }),
    password = UI.TextEntry({
      x = center,
      y = math.floor(UI.term.height / 2),
      width = 8,
      limit = 8 
    }),
    statusBar = UI.StatusBar(),
    accelerators = {
      q = 'back',
    },
  })

  function page:eventHandler(event)
    if event.type == 'key' and event.key == 'enter' then
      Config.load('os', config)
      if SHA1.sha1(self.password.value) == config.password then
        os.locked = false
        Event.exitPullEvents()
        lockId = false
        return true
      else
        self.statusBar:timedStatus('Invalid Password', 3)
      end
    end
    UI.Page.eventHandler(self, event)
  end

  UI:setPage(page)
  Event.pullEvents()
end

function os.verifyPassword(password)
  Config.load('os', config)
  return config.password and password == config.password
end

function os.getSecretKey()
  Config.load('os', config)
  if not config.secretKey then
    config.secretKey = math.random(100000, 999999)
    Config.update('os', config)
  end
  return config.secretKey
end

function os.updatePassword(password)
  Config.load('os', config)
  config.password = password
  Config.update('os', config)
end

function os.getPassword()
  Config.load('os', config)
  return config.password
end

os.lock = function()
  --os.locked = true

  if not lockId then
    lockId = multishell.openTab({
      title = 'Lock',
      env = getfenv(1),
      fn = lockScreen,
      focused = true,
    })
  end
end

os.unlock = function()
  os.locked = false

  if lockId then
    multishell.terminate(lockId)
    lockId = nil
  end
end

function os.isTurtle()
  return not not turtle
end

function os.isAdvanced()
  return term.native().isColor()
end

function os.isPocket()
  return not not pocket
end

function os.getVersion()
  local version

  if _CC_VERSION then
    version = tonumber(_CC_VERSION:gmatch('[%d]+%.?[%d][%d]', '%1')())
  end
  if not version and _HOST then
    version = tonumber(_HOST:gmatch('[%d]+%.?[%d][%d]', '%1')())
  end

  return version or 1.7
end

function os.registerApp(entry)
  local apps = { }
  Config.load('apps', apps)

  local run = fs.combine(entry.run, '')

  for k,app in pairs(apps) do
    if app.run == run then
      table.remove(apps, k)
      break
    end
  end

  table.insert(apps, {
    run = run,
    title = entry.title,
    args = entry.args,
    category = entry.category,
    icon = entry.icon,
  })

  Config.update('apps', apps)

  os.queueEvent('os_register_app')
end

function os.unregisterApp(run)

  local apps = { }
  Config.load('apps', apps)

  local run = fs.combine(run, '')

  for k,app in pairs(apps) do
    if app.run == run then
      table.remove(apps, k)
      Config.update('apps', apps)
      os.queueEvent('os_register_app')
      break
    end
  end
end

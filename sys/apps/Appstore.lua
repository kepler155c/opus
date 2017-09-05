requireInjector(getfenv(1))

local Config = require('config')
local SHA1   = require('sha1')
local UI     = require('ui')
local Util   = require('util')

-- scrap this entire file. don't muck with standard apis

local REGISTRY_DIR = 'usr/.registry'


--                                           FIX SOMEDAY
function os.registerApp(app, key)

  app.key = SHA1.sha1(key)
  Util.writeTable(fs.combine(REGISTRY_DIR, app.key), app)
  os.queueEvent('os_register_app')
end

function os.unregisterApp(key)

  local filename = fs.combine(REGISTRY_DIR, SHA1.sha1(key))
  if fs.exists(filename) then
    fs.delete(filename)
    os.queueEvent('os_register_app')
  end
end


local sandboxEnv = Util.shallowCopy(getfenv(1))
setmetatable(sandboxEnv, { __index = _G })

multishell.setTitle(multishell.getCurrent(), 'App Store')
UI:configure('Appstore', ...)

local APP_DIR = 'usr/apps'

local sources = {

  { text = "STD Default",
    event = 'source',
    url = "http://pastebin.com/raw/zVws7eLq" }, --stock
--[[
  { text = "Discover",
    event = 'source',
    generateName = true,
    url = "http://pastebin.com/raw/9bXfCz6M" }, --owned by dannysmc95

  { text = "Opus",
    event = 'source',
    url = "http://pastebin.com/raw/ajQ91Rmn" },
]]
}

shell.setDir(APP_DIR)

function downloadApp(app)
  local h

  if type(app.url) == "table" then
    h = contextualGet(app.url[1])
  else
    h = http.get(app.url)
  end

  if h then
    local contents = h.readAll()
    h:close()
    return contents
  end
end

function runApp(app, checkExists, ...)

  local path, fn
  local args = { ... }

  if checkExists and fs.exists(fs.combine(APP_DIR, app.name)) then
    path = fs.combine(APP_DIR, app.name)
  else
    local program = downloadApp(app)

    fn = function() 

      if not program then
        error('Failed to download')
      end

      local fn = loadstring(program, app.name)

      if not fn then
        error('Failed to download')
      end

      setfenv(fn, sandboxEnv)
      fn(unpack(args))
    end
  end

  multishell.openTab({
    title = app.name,
    env = sandboxEnv,
    path = path,
    fn = fn,
    focused = true,
  })

  return true, 'Running program'
end

local installApp = function(app)

  local program = downloadApp(app)
  if not program then
    return false, "Failed to download"
  end

  local fullPath = fs.combine(APP_DIR, app.name)
  Util.writeFile(fullPath, program)
  return true, 'Installed as ' .. fullPath
end

local viewApp = function(app)

  local program = downloadApp(app)
  if not program then
    return false, "Failed to download"
  end

  Util.writeFile('/.source', program)
  shell.openForegroundTab('edit /.source')
  fs.delete('/.source')
  return true
end

local getSourceListing = function(source)
  local contents = http.get(source.url)
  if contents then

    local fn = loadstring(contents.readAll(), source.text)
    contents.close()

    local env = { std = { } }
    setmetatable(env, { __index = _G })
    setfenv(fn, env)
    fn()

    if env.contextualGet then
      contextualGet = env.contextualGet
    end

    source.storeURLs = env.std.storeURLs
    source.storeCatagoryNames = env.std.storeCatagoryNames

    if source.storeURLs and source.storeCatagoryNames then
      for k,v in pairs(source.storeURLs) do
        if source.generateName then
          v.name = v.title:match('(%w+)')
          if not v.name or #v.name == 0 then
            v.name = tostring(k)
          else
            v.name = v.name:lower()
          end
        else
          v.name = k
        end
        v.categoryName = source.storeCatagoryNames[v.catagory]
        v.ltitle = v.title:lower()
      end
    end
  end
end

local appPage = UI.Page({
  backgroundColor = UI.ViewportWindow.defaults.backgroundColor,
  menuBar = UI.MenuBar({
    showBackButton = not pocket,
    buttons = {
      { text = 'Install', event = 'install' },
      { text = 'Run',     event = 'run'     },
      { text = 'View',    event = 'view'    },
      { text = 'Remove',  event = 'uninstall', name = 'removeButton' },
    },
  }),
  container = UI.Window({
    x = 2,
    y = 3,
    height = UI.term.height - 3,
    width = UI.term.width - 2,
    viewport = UI.ViewportWindow(),
  }),
  notification = UI.Notification(),
  accelerators = {
    q = 'back',
    backspace = 'back',
  },
})

function appPage.container.viewport:draw()
  local app = self.parent.parent.app
  local str = string.format(
    'By: %s\nCategory: %s\nFile name: %s\n\n%s',
    app.creator, app.categoryName, app.name, app.description)

  self:clear()
  local y = self:wrappedWrite(1, 1, app.title, self.width, nil, colors.yellow)
  self.height = self:wrappedWrite(1, y, str, self.width)

  if appPage.notification.enabled then
    appPage.notification:draw()
  end
end

function appPage:enable(source, app)
  self.source = source
  self.app = app
  UI.Page.enable(self)

  self.container.viewport:setScrollPosition(0)
  if fs.exists(fs.combine(APP_DIR, app.name)) then
    self.menuBar.removeButton:enable('Remove')
  else
    self.menuBar.removeButton:disable('Remove')
  end
end

function appPage:eventHandler(event)
  if event.type == 'back' then
    UI:setPreviousPage()

  elseif event.type == 'run' then
    self.notification:info('Running program', 3)
    self:sync()
    runApp(self.app, true)

  elseif event.type == 'view' then
    self.notification:info('Downloading program', 3)
    self:sync()
    viewApp(self.app)

  elseif event.type == 'uninstall' then
    if self.app.runOnly then
      s,m = runApp(self.app, false, 'uninstall')
    else
      fs.delete(fs.combine(APP_DIR, self.app.name))
      self.notification:success("Uninstalled " .. self.app.name, 3)
      self:focusFirst(self)
      self.menuBar.removeButton:disable('Remove')
      self.menuBar:draw()

      os.unregisterApp(self.app.creator .. '.' .. self.app.name)
    end

  elseif event.type == 'install' then
    self.notification:info("Installing", 3)
    self:sync()
    local s, m
    if self.app.runOnly then
      s,m = runApp(self.app, false)
    else
      s,m = installApp(self.app)
    end
    if s then
      self.notification:success(m, 3)

      if not self.app.runOnly then
        self.menuBar.removeButton:enable('Remove')
        self.menuBar:draw()

        local category = 'Apps'
        if self.app.catagoryName == 'Game' then
          category = 'Games'
        end

        os.registerApp({
          run = fs.combine(APP_DIR, self.app.name),
          title = self.app.title,
          category = category,
          icon = self.app.icon,
        }, self.app.creator .. '.' .. self.app.name)
      end
    else
      self.notification:error(m, 3)
    end
  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

local categoryPage = UI.Page({
  menuBar = UI.MenuBar({
    buttons = {
      { text = 'Catalog',  event = 'dropdown', dropdown = 'sourceMenu'   },
      { text = 'Category', event = 'dropdown', dropdown = 'categoryMenu' },
    },
  }),
  sourceMenu = UI.DropMenu({
    buttons = sources,
  }),
  grid = UI.ScrollingGrid({
    y = 2,
    height = UI.term.height - 2,
    columns = {
      { heading = 'Title', key = 'title' },
    },
    sortColumn = 'title',
    autospace = true,
  }),
  statusBar = UI.StatusBar(),
  accelerators = {
    l = 'lua',
    q = 'quit',
  },
})

function categoryPage:setCategory(source, name, index)
  self.grid.values = { }
  for k,v in pairs(source.storeURLs) do
    if index == 0 or index == v.catagory then
      table.insert(self.grid.values, v)
    end
  end
  self.statusBar:setStatus(string.format('%s: %s', source.text, name))
  self.grid:update()
  self.grid:setIndex(1)
end

function categoryPage:setSource(source)

  if not source.categoryMenu then

    self.statusBar:setStatus('Loading...')
    self.statusBar:draw()
    self:sync()

    getSourceListing(source)

    if not source.storeURLs then
      error('Unable to download application list')
    end

    local buttons = { }
    for k,v in Util.spairs(source.storeCatagoryNames, 
          function(a, b) return a:lower() < b:lower() end) do

      if v ~= 'Operating System' then
        table.insert(buttons, {
          text = v,
          event = 'category',
          index = k,
        })
      end
    end

    source.categoryMenu = UI.DropMenu({
      y = 2,
      x = 1,
      buttons = buttons,
    })
    source.index, source.name = Util.first(source.storeCatagoryNames)

    categoryPage:add({
      categoryMenu = source.categoryMenu
    })
  end

  self.source = source
  self.categoryMenu = source.categoryMenu
  categoryPage:setCategory(source, source.name, source.index)
end

function categoryPage.grid:sortCompare(a, b)
  return a.ltitle < b.ltitle
end

function categoryPage.grid:getRowTextColor(row, selected)
  if fs.exists(fs.combine(APP_DIR, row.name)) then
    return colors.orange
  end
  return UI.Grid:getRowTextColor(row, selected)
end

function categoryPage:eventHandler(event)

  if event.type == 'grid_select' or event.type == 'select' then
    UI:setPage(appPage, self.source, self.grid:getSelected())

  elseif event.type == 'category' then
    self:setCategory(self.source, event.button.text, event.button.index)
    self:setFocus(self.grid)
    self:draw()

  elseif event.type == 'source' then
    self:setFocus(self.grid)
    self:setSource(event.button)
    self:draw()

  elseif event.type == 'quit' then
    UI:exitPullEvents()

  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

print("Retrieving catalog list")
categoryPage:setSource(sources[1])

UI:setPage(categoryPage)
UI:pullEvents()
UI.term:reset()

requireInjector(getfenv(1))

local Config = require('config')
local Event  = require('event')
local Socket = require('socket')
local UI     = require('ui')
local Util   = require('util')

local GROUPS_PATH = 'usr/groups'
local SCRIPTS_PATH = 'usr/etc/scripts'

multishell.setTitle(multishell.getCurrent(), 'Script')
UI:configure('script', ...)

local config = {
  showGroups = false,
  variables = [[{
    COMPUTER_ID = os.getComputerID(),
  }]],
}

Config.load('script', config)

local width = math.floor(UI.term.width / 2) - 1
if UI.term.width % 2 ~= 0 then
  width = width + 1
end

function processVariables(script)

  local fn = loadstring('return ' .. config.variables)
  if fn then
    local variables = fn()

    for k,v in pairs(variables) do
      local token = string.format('{%s}', k)
      script = script:gsub(token, v)
    end
  end
  return script
end

function invokeScript(computer, scriptName)

  local script = Util.readFile(scriptName)
  if not script then
    print('Unable to read script file')
  end

  local socket = Socket.connect(computer.id, 161)
  if not socket then
    print('Unable to connect to ' .. computer.id)
    return
  end

  script = processVariables(script)

  Util.print('Running %s on %s', scriptName, computer.label)
  socket:write({ type = 'script', args = script })
  --[[
  local response = socket:read(2)

  if response and response.result then
    if type(response.result) == 'table' then
      print(textutils.serialize(response.result))
    else
      print(tostring(response.result))
    end
  else
    printError('No response')
  end
  --]]

  socket:close()
end

function runScript(computerOrGroup, scriptName)
  if computerOrGroup.id then
    invokeScript(computerOrGroup, scriptName)
  else
    local list = computerOrGroup.list
    if computerOrGroup.path then
      list = Util.readTable(computerOrGroup.path)
    end
    if list then
      for _,computer in pairs(list) do
        invokeScript(computer, scriptName)
      end
    end
  end
end

local function getActiveComputers(t)
  t = t or { }
  Util.clear(t)
  for k,computer in pairs(_G.network) do
    if computer.active then
      t[k] = computer
    end
  end
  return t
end

local function getTurtleList()
  local turtles = {
    label = 'Turtles',
    list = { },
  }
  for k,computer in pairs(getActiveComputers()) do
    if computer.fuel then
      turtles.list[k] = computer
    end
  end
  return turtles
end

local args = { ... }
if #args == 2 then
  local key = args[1]
  local script = args[2]
  local target
  if tonumber(key) then
    target = _G.network[tonumber(key)]
  elseif key == 'All' then
    target = {
      list = Util.shallowCopy(getActiveComputers()),
    }
  elseif key == 'Localhost' then
    target = { id = os.getComputerID() }
  elseif key == 'Turtles' then
    target = getTurtleList()
  else
    target = Util.readTable(fs.combine(GROUPS_PATH, key))
  end

  if not target then
    error('Syntax: Script <ID or group> <script>')
  end

  runScript(target, fs.combine(SCRIPTS_PATH, script))
  return
end

local function getListing(t, path)
  Util.clear(t)
  local files = fs.list(path)
  for _,f in pairs(files) do
    table.insert(t, { label = f, path = fs.combine(path, f) })
  end
end

local mainPage = UI.Page({
  menuBar = UI.MenuBar({
    buttons = {
      { text = 'Groups', event = 'groups' },
      { text = 'Scripts', event = 'scripts' },
      { text = 'Toggle', event = 'toggle' },
    },
  }),
  computers = UI.ScrollingGrid({
    y = 2,
    height = UI.term.height-3,
    columns = {
      { heading = 'Label', key = 'label', width = width },
    },
    width = width,
    sortColumn = 'label',
  }),
  scripts = UI.ScrollingGrid({
    columns = {
      { heading = 'Name', key = 'label', width = width },
    },
    sortColumn = 'label',
    height = UI.term.height - 3,
    width = width,
    x = UI.term.width - width + 1,
    y = 2,
  }),
  statusBar = UI.StatusBar({
    columns = {
      { '', 'status', 4 },
      { '', 'fuelF', 5 },
      { '', 'distanceF', 4 },
    },
    autospace = true,
  }),
  accelerators = {
    q = 'quit',
  },
})

local editorPage = UI.Page({
  menuBar = UI.MenuBar({
    showBackButton = true,
    buttons = {
      { text = 'Save', event = 'save', help = 'Save this group' },
    },
  }),
  grid1 = UI.ScrollingGrid({
    columns = {
      { heading = 'Name', key = 'label', width = width },
    },
    sortColumn = 'label',
    height = UI.term.height - 4,
    width = width,
    y = 3,
  }),
  right = UI.Button({
    text = '>', 
    event = 'right',
    x = width - 2,
    y = 2,
    width = 3,
  }),
  left = UI.Button({
    text = '<', 
    event = 'left',
    x = UI.term.width - width + 1,
    y = 2,
    width = 3,
  }),
  grid2 = UI.ScrollingGrid({
    columns = {
      { heading = 'Name', key = 'label', width = width },
    },
    sortColumn = 'label',
    height = UI.term.height - 4,
    width = width,
    x = UI.term.width - width + 1,
    y = 3,
  }),
  statusBar = UI.StatusBar(),
  accelerators = {
    q = 'back',
  },
})

local groupsPage = UI.Page({
  menuBar = UI.MenuBar({
    showBackButton = true,
    buttons = {
      { text = 'Add',    event = 'add'    },
      { text = 'Edit',   event = 'edit'   },
      { text = 'Delete', event = 'delete' },
    },
  }),
  grid = UI.ScrollingGrid({
    y = 2,
    height = UI.term.height-2,
    columns = {
      { heading = 'Name', key = 'label' },
    },
    sortColumn = 'label',
    autospace = true,
  }),
  statusBar = UI.StatusBar(),
  accelerators = {
    q = 'back',
  },
})

local scriptsPage = UI.Page({
  menuBar = UI.MenuBar({
    showBackButton = true,
    buttons = {
      { text = 'Add',    event = 'add'    },
      { text = 'Edit',   event = 'edit'   },
      { text = 'Delete', event = 'delete' },
    },
  }),
  grid = UI.ScrollingGrid({
    y = 2,
    height = UI.term.height-2,
    columns = {
      { heading = 'Name', key = 'label' },
    },
    sortColumn = 'label',
    autospace = true,
  }),
  statusBar = UI.StatusBar(),
  accelerators = {
    a = 'add',
    e = 'edit',
    delete = 'delete',
    q = 'back',
  },
})

function editorPage:enable()
  self:focusFirst()

  local groupPath = fs.combine(GROUPS_PATH, self.groupName)
  if fs.exists(groupPath) then
    self.grid1.values = Util.readTable(groupPath)
  else
    Util.clear(self.grid1.values)
  end
  self.grid1:update()
  UI.Page.enable(self)
end

function editorPage.grid2:draw()

  getActiveComputers(self.values)

  for k in pairs(editorPage.grid1.values) do
    self.values[k] = nil
  end
  self:update()

  UI.ScrollingGrid.draw(self)
end

function editorPage:eventHandler(event)

  if event.type == 'back' then
    UI:setPage(groupsPage)

  elseif event.type == 'left' then
    local computer = self.grid2:getSelected()
    self.grid1.values[computer.id] = computer
    self.grid1:update()
    self.grid1:draw()
    self.grid2:draw()

  elseif event.type == 'right' then
    local computer = self.grid1:getSelected()
    self.grid1.values[computer.id] = nil
    self.grid1:update()
    self.grid1:draw()
    self.grid2:draw()

  elseif event.type == 'save' then
    Util.writeTable(fs.combine(GROUPS_PATH, self.groupName), self.grid1.values)
    UI:setPage(groupsPage)
  end

  return UI.Page.eventHandler(self, event)
end

local function nameDialog(f)
  local dialog = UI.Dialog({
--    x = (UI.term.width - 28) / 2,
    width = 22,
    title = 'Enter Name',
    form = UI.Form {
      x = 2, rex = -2, y = 2,
      textEntry = UI.TextEntry({ y = 3, width = 20, limit = 20 })
    },
  })

  dialog.eventHandler = function(self, event)
    if event.type == 'form_complete' then
      local name = self.form.textEntry.value
      if name then
        f(name)
      else
        self.statusBar:timedStatus('Invalid Name', 3)
      end
      return true
    elseif event.type == 'form_cancel' or event.type == 'cancel' then
      UI:setPreviousPage()
    else
      return UI.Dialog.eventHandler(self, event)
    end
  end

  dialog:setFocus(dialog.form.textEntry)
  UI:setPage(dialog)
end

function groupsPage:draw()
  getListing(self.grid.values, GROUPS_PATH)
  self.grid:update()
  UI.Page.draw(self)
end

function groupsPage:enable()
  self:focusFirst()
  UI.Page.enable(self)
end

function groupsPage:eventHandler(event)

  if event.type == 'back' then
    UI:setPage(mainPage)

  elseif event.type == 'add' then
    nameDialog(function(name)
        editorPage.groupName = name
        UI:setPage(editorPage)
      end)

  elseif event.type == 'delete' then
    fs.delete(fs.combine(GROUPS_PATH, self.grid:getSelected().label))
    self:draw()

  elseif event.type == 'edit' then
    editorPage.groupName = self.grid:getSelected().label
    UI:setPage(editorPage)
  end

  return UI.Page.eventHandler(self, event)
end

function scriptsPage:draw()
  getListing(self.grid.values, SCRIPTS_PATH)
  self.grid:update()
  UI.Page.draw(self)
end

function scriptsPage:enable()
  self:focusFirst()
  UI.Page.enable(self)
end

function scriptsPage:eventHandler(event)

  if event.type == 'back' then
    UI:setPreviousPage()

  elseif event.type == 'add' then
    nameDialog(function(name)
        shell.run('edit ' .. fs.combine(SCRIPTS_PATH, name))
        UI:setPreviousPage()
      end)

  elseif event.type == 'edit' then
    local name = fs.combine(SCRIPTS_PATH, self.grid:getSelected().label)
    shell.run('edit  ' .. name)
    self:draw()

  elseif event.type == 'delete' then
    local name = fs.combine(SCRIPTS_PATH, self.grid:getSelected().label)
    fs.delete(name)
    self:draw()
  end

  return UI.Page.eventHandler(self, event)
end

function mainPage:eventHandler(event)

  if event.type == 'quit' then
    Event.exitPullEvents()

  elseif event.type == 'groups' then
    UI:setPage(groupsPage)

  elseif event.type == 'scripts' then
    UI:setPage(scriptsPage)

  elseif event.type == 'toggle' then
    config.showGroups = not config.showGroups
    local text = 'Computers'
    if config.showGroups then
      text = 'Groups'
    end
--    self.statusBar.toggleButton.text = text
    self:draw()

    Config.update('script', config)

  elseif event.type == 'grid_focus_row' then
    local computer = self.computers:getSelected()
    self.statusBar.values = { computer }
    self.statusBar:draw()

  elseif event.type == 'grid_select' then

    local script = self.scripts:getSelected()
    local computer = self.computers:getSelected()

    self:clear()
    self:sync()
    self.enabled = false
    runScript(computer, script.path)
    print()
    print('Press any key to continue...')
    while true do
      local e = os.pullEvent()
      if e == 'char' or e == 'key' or e == 'mouse_click' then
        break
      end
    end
    self.enabled = true
    self:draw()
  end

  return UI.Page.eventHandler(self, event)
end

function mainPage.statusBar:draw()
  local computer = self.values[1]
  if computer then
    if computer.fuel then
      computer.fuelF = string.format("%dk", math.floor(computer.fuel/1000))
    end
    if computer.distance then
      computer.distanceF = Util.round(computer.distance, 1)
    end
    mainPage.statusBar:adjustWidth()
  end
  UI.StatusBar.draw(self)
end

function mainPage:draw()
  getListing(self.scripts.values, SCRIPTS_PATH)

  if config.showGroups then
    getListing(self.computers.values, GROUPS_PATH)
    table.insert(self.computers.values, {
      label = 'All',
      list = getActiveComputers(),
    })
    table.insert(self.computers.values, getTurtleList())
    table.insert(self.computers.values, {
      label = 'Localhost',
      id = os.getComputerID(),
    })
  else
    getActiveComputers(self.computers.values)
  end
  self.scripts:update()
  self.computers:update()
  UI.Page.draw(self)
end

if not fs.exists(SCRIPTS_PATH) then
  fs.makeDir(SCRIPTS_PATH)
end

if not fs.exists(GROUPS_PATH) then
  fs.makeDir(GROUPS_PATH)
end

Event.on('network_attach', function()
  if mainPage.enabled then
    mainPage:draw()
  end
end)

Event.on('network_detach', function()
  if mainPage.enabled then
    mainPage:draw()
  end
end)

Event.onInterval(1, function()
  if mainPage.enabled then
    local selected = mainPage.computers:getSelected()
    if selected then
      local computer = _G.network[selected.id]
      mainPage.statusBar.values = { computer }
      mainPage.statusBar:draw()
      mainPage:sync()
    end
  end
end)

UI:setPage(mainPage)
UI:pullEvents()
UI.term:reset()

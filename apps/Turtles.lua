require = requireInjector(getfenv(1))
local Event = require('event')
local UI = require('ui')
local Socket = require('socket')
local Terminal = require('terminal')

multishell.setTitle(multishell.getCurrent(), 'Turtles')
UI.Button.defaults.focusIndicator = ' '
UI:configure('Turtles', ...)

local options = {
  turtle      = { arg = 'i', type = 'number', value = -1,
                 desc = 'Turtle ID' },
  tab         = { arg = 's', type = 'string', value = 'inventory',
                 desc = 'Selected tab to display' },
  help        = { arg = 'h', type = 'flag',   value = false,
                 desc = 'Displays the options' },
}

local SCRIPTS_PATH = '/apps/scripts'

local ct = term.current()
local nullTerm = Terminal.getNullTerm(term.current())
local turtles = { }
local policies = { 
  { label = 'none' },
  { label = 'digOnly' },
  { label = 'attackOnly' },
  { label = 'digAttack' },
  { label = 'turtleSafe' },
}

local page = UI.Page {
  moveUp = UI.Button {
    x = 5, y = 2,
    text = '/\\',
    fn = 'turtle.up',
  },
  moveDown = UI.Button {
    x = 5, y = 4,
    text = '\\/',
    fn = 'turtle.down',
  },
  moveForward = UI.Button {
    x = 9, y = 3,
    text = '>',
    fn = 'turtle.forward',
  },
  moveBack = UI.Button {
    x = 2, y = 3,
    text = '<',
    fn = 'turtle.back',
  },
  turnLeft = UI.Button {
    x = 2, y = 6,
    text = '<-',
    fn = 'turtle.turnLeft',
  },
  turnRight = UI.Button {
    x = 8, y = 6,
    text = '->',
    fn = 'turtle.turnRight',
  },
--[[
  policy = UI.Chooser {
    x = 2, y = 8,
    choices = {
      { name = ' None ', value = 'none'       },
      { name = ' Safe ', value = 'turtleSafe' },
    },
  },
]]
  coords = UI.Window {
    x = 14, y = 2, height = 5, rex = -2,
  },
  tabs = UI.Tabs {
    x = 1, y = 8, rey = -2,
    scripts = UI.Grid {
      tabTitle = 'Run',
      columns = {
        { heading = '', key = 'label'  },
      },
      disableHeader = true,
      sortColumn = 'label',
      autospace = true,
    },
    turtles = UI.Grid {
      tabTitle = 'Sel',
      columns = {
        { heading = 'label',  key = 'label'    },
        { heading = 'Dist',   key = 'distance' },
        { heading = 'Status', key = 'status'   },
        { heading = 'Fuel',   key = 'fuel'     },
      },
      disableHeader = true,
      sortColumn = 'label',
      autospace = true,
    },
    inventory = UI.Grid {
      tabTitle = 'Inv',
      columns = {
        { heading = '',          key = 'qty', width = 2   },
        { heading = 'Inventory', key = 'id',  width = 13  },
      },
      disableHeader = true,
      sortColumn = 'index',
    },
    policy = UI.Grid {
      tabTitle = 'Mod',
      columns = {
        { heading = 'label', key = 'label'  },
      },
      values = policies,
      disableHeader = true,
      sortColumn = 'label',
      autospace = true,
    },
  },
  statusBar = UI.StatusBar(),
  notification = UI.Notification(),
  accelerators = {
    q = 'quit',
  },
}

function page:enable(turtle)
  self.turtle = turtle
  UI.Page.enable(self)
end

function page:runFunction(script, nowrap)

  local socket = Socket.connect(self.turtle.id, 161)
  if not socket then
    self.notification:error('Unable to connect')
    return
  end

  if not nowrap then
    script = 'turtle.run(' .. script .. ')'
  end
  socket:write({ type = 'script', args = script })
  socket:close()
end

function page:runScript(scriptName)
  local cmd = string.format('Script %d %s', self.turtle.id, scriptName)
  local ot = term.redirect(nullTerm)
  pcall(function() shell.run(cmd) end)
  term.redirect(ot)
end

function page.coords:draw()
  local t = self.parent.turtle
  if t then
    self:clear()
    self:setCursorPos(1, 1)
    self:print(string.format('%s\nx: %d\ny: %d\nz: %d\nFuel: %s\n', 
      t.coordSystem, t.point.x, t.point.y, t.point.z, Util.toBytes(t.fuel)))
  end
end

--[[ Inventory Tab ]]--
function page.tabs.inventory:getRowTextColor(row, selected)
  if page.turtle and row.selected then
    return colors.yellow
  end
  return UI.Grid.getRowTextColor(self, row, selected)
end

function page.tabs.inventory:draw()
  local t = page.turtle
  Util.clear(self.values)
  if t then
    for _,v in ipairs(t.inventory) do
      if v.qty > 0 then
        table.insert(self.values, v)
        if v.index == t.slotIndex then
          v.selected = true
        end
        if v.id then
          v.id = v.id:gsub('.*:(.*)', '%1')
        end
      end
    end
  end
  self:adjustWidth()
  self:update()
  UI.Grid.draw(self)
end

function page.tabs.inventory:eventHandler(event)
  if event.type == 'grid_select' then
    local fn = string.format('turtle.select(%d)', event.selected.index)
    page:runFunction(fn)
  else
    return UI.Grid.eventHandler(self, event)
  end
  return true
end

function page.tabs.scripts:draw()
  Util.clear(self.values)
  local files = fs.list(SCRIPTS_PATH)
  for _,f in pairs(files) do
    table.insert(self.values, { label = f, path = fs.combine(SCRIPTS_PATH, f) })
  end
  self:update()
  UI.Grid.draw(self)
end

function page.tabs.scripts:eventHandler(event)
  if event.type == 'grid_select' then
    page:runScript(event.selected.label)
  else
    return UI.Grid.eventHandler(self, event)
  end
  return true
end

function page.tabs.turtles:getDisplayValues(row)
  row = Util.shallowCopy(row)
  if row.fuel then
    row.fuel = Util.toBytes(row.fuel)
  end
  if row.distance then
    row.distance = Util.round(row.distance, 1)
  end
  return row
end

function page.tabs.turtles:draw()
  Util.clear(self.values)
  for _,v in pairs(network) do
    if v.fuel then
      table.insert(self.values, v)
    end
  end
  self:update()
  UI.Grid.draw(self)
end

function page.tabs.turtles:eventHandler(event)
  if event.type == 'grid_select' then
    page.turtle = event.selected
  else
    return UI.Grid.eventHandler(self, event)
  end
  return true
end

function page.statusBar:draw()
  local t = self.parent.turtle
  if t then
    local status = string.format('%s [ %s ]', t.status, Util.round(t.distance, 2))
    self:setStatus(status, true)
  end
  UI.StatusBar.draw(self)
end

function page:eventHandler(event)
  if event.type == 'quit' then
    UI:setPreviousPage()
  elseif event.type == 'button_press' then
    if event.button.fn then
      self:runFunction(event.button.fn, event.button.nowrap)
    elseif event.button.script then
      self:runScript(event.button.script)
    end
  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

function page:enable()
  UI.Page.enable(self)
--  self.tabs:activateTab(page.tabs.turtles)
end

local function updateThread()

  while true do
    if page.turtle then
      local t = _G.network[page.turtle.id]
      page.turtle = t
      page:draw()
      page:sync()
    end

    os.sleep(1)
  end
end

if not Util.getOptions(options, { ... }, true) then
  return
end

if options.turtle.value then
  page.turtle = _G.network[options.turtle.value]
end

UI:setPage(page)

page.tabs:activateTab(page.tabs[options.tab.value])

Event.pullEvents(updateThread)
UI.term:reset()

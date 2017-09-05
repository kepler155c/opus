requireInjector(getfenv(1))

local Event = require('event')
local UI    = require('ui')
local Util  = require('util')

multishell.setTitle(multishell.getCurrent(), 'Devices')

--[[ -- PeripheralsPage  -- ]] --
local peripheralsPage = UI.Page {
  grid = UI.ScrollingGrid {
    columns = { 
      { heading = 'Type', key = 'type' },
      { heading = 'Side', key = 'side' },
    },  
    sortColumn = 'type',
    height = UI.term.height - 1,
    autospace = true,
  },
  statusBar = UI.StatusBar {
    status = 'Select peripheral'
  },
  accelerators = {
    q = 'quit',
  },
}

function peripheralsPage.grid:draw()
  local sides = peripheral.getNames()

  Util.clear(self.values)
  for _,side in pairs(sides) do
    table.insert(self.values, {
      type = peripheral.getType(side),
      side = side
    })
  end
  self:update()
  self:adjustWidth()
  UI.Grid.draw(self)
end

function peripheralsPage:updatePeripherals()
  if UI:getCurrentPage() == self then
    self.grid:draw()
    self:sync()
  end
end

function peripheralsPage:eventHandler(event)
  if event.type == 'quit' then
    Event.exitPullEvents()

  elseif event.type == 'grid_select' then
    UI:setPage('methods', event.selected)

  end
  return UI.Page.eventHandler(self, event)
end

--[[ -- MethodsPage  -- ]] --
local methodsPage = UI.Page {
  grid = UI.ScrollingGrid {
    columns = { 
      { heading = 'Name', key = 'name', width = UI.term.width }
    },  
    sortColumn = 'name',
    height = 7,
  },
  viewportConsole = UI.ViewportWindow {
    y = 8,
    height = UI.term.height - 8,
    backgroundColor = colors.brown,
  },
  statusBar = UI.StatusBar {
    status = 'q to return',
  },
  accelerators = {
    q = 'back',
    backspace = 'back',
  },
}

function methodsPage:enable(p)

  self.peripheral = p or self.peripheral

  local p = peripheral.wrap(self.peripheral.side)
  if p.getDocs then
    self.grid.values = { }
    for k,v in pairs(p.getDocs()) do
      table.insert(self.grid.values, {
        name = k,
        doc = v,
      })
    end
  elseif not p.getAdvancedMethodsData then
    self.grid.values = { }
    for name,f in pairs(p) do
      table.insert(self.grid.values, {
        name = name,
        noext = true,
      })
    end
  else
    self.grid.values = p.getAdvancedMethodsData()
    for name,f in pairs(self.grid.values) do
      f.name = name
    end
  end

  self.viewportConsole.offy = 0

  self.grid:update()
  self.grid:setIndex(1)

  self.statusBar:setStatus(self.peripheral.type)
  UI.Page.enable(self)
end

function methodsPage:eventHandler(event)
  if event.type == 'back' then
    UI:setPage(peripheralsPage)
    return true
  elseif event.type == 'grid_focus_row' then
    self.viewportConsole.offy = 0
    self.viewportConsole:draw()
  end
  return UI.Page.eventHandler(self, event)
end

function methodsPage.viewportConsole:draw()
  local c = self
  local method = methodsPage.grid:getSelected()

  c:clear()
  c:setCursorPos(1, 1)

  if method.noext then
    c.cursorY = 2
    c:print('No extended Information')
    return 2
  end

  if method.doc then
    c:print(method.doc, nil, colors.yellow)
    c.ymax = c.cursorY + 1
    return
  end

  if method.description then
    c:print(method.description)
  end

  c.cursorY = c.cursorY + 2
  c.cursorX = 1

  if method.returnTypes ~= '()' then
    c:print(method.returnTypes .. ' ', nil, colors.yellow)
  end
  c:print(method.name, nil, colors.black)
  c:print('(')

  local maxArgLen = 1

  for k,arg in ipairs(method.args) do
    if #arg.description > 0 then
      maxArgLen = math.max(#arg.name, maxArgLen)
    end
    local argName = arg.name
    local fg = colors.green
    if arg.optional then
      argName = string.format('[%s]', arg.name)
      fg = colors.orange
    end
    c:print(argName, nil, fg)
    if k < #method.args then
      c:print(', ')
    end
  end
  c:print(')')

  c.cursorY = c.cursorY + 1

  if #method.args > 0 then
    for _,arg in ipairs(method.args) do
      if #arg.description > 0 then
        c.cursorY = c.cursorY + 1
        c.cursorX = 1
        local fg = colors.green
        if arg.optional then
          fg = colors.orange
        end
        c:print(arg.name .. ': ', nil, fg)
        c.cursorX = maxArgLen + 3
        c:print(arg.description, nil, nil, maxArgLen + 3)
      end
    end
  end

  c.ymax = c.cursorY + 1
end

Event.on('peripheral', function()
  peripheralsPage:updatePeripherals()
end)

Event.on('peripheral_detach', function()
  peripheralsPage:updatePeripherals()
end)

UI:setPage(peripheralsPage)

UI:setPages({
  methods = methodsPage,
})

UI:pullEvents()

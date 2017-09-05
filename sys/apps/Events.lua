requireInjector(getfenv(1))

local Event = require('event')
local UI    = require('ui')
local Util  = require('util')

multishell.setTitle(multishell.getCurrent(), 'Events')
UI:configure('Events', ...)

local page = UI.Page({
  menuBar = UI.MenuBar({
    buttons = {
      { text = 'Filter', event = 'filter' },
      { text = 'Reset',  event = 'reset'  },
      { text = 'Pause ', event = 'toggle', name = 'pauseButton' },
    },
  }),
  grid = UI.Grid({
    y = 2,
    columns = {
      { heading = 'Event', key = 'event' },
      { key = 'p1' },
      { key = 'p2' },
      { key = 'p3' },
      { key = 'p4' },
      { key = 'p5' },
    },
    autospace = true,
  }),
  accelerators = {
    f = 'filter',
    p = 'toggle',
    r = 'reset',
    c = 'clear',
    q = 'quit',
  },
  filtered = { },
})

function page:eventHandler(event)

  if event.type == 'filter' then
    local entry = self.grid:getSelected()
    self.filtered[entry.event] = true

  elseif event.type == 'toggle' then
    self.paused = not self.paused
    if self.paused then
      self.menuBar.pauseButton.text = 'Resume'
    else
      self.menuBar.pauseButton.text = 'Pause '
    end
    self.menuBar:draw()

  elseif event.type == 'grid_select' then
    multishell.openTab({ path = 'sys/apps/Lua.lua', args = { event.selected }, focused = true })

  elseif event.type == 'reset' then
    self.filtered = { }
    self.grid:setValues({ })
    self.grid:draw()
    if self.paused then
      self:emit({ type = 'toggle' })
    end

  elseif event.type == 'clear' then
    self.grid:setValues({ })
    self.grid:draw()

  elseif event.type == 'quit' then
    Event.exitPullEvents()

  elseif event.type == 'focus_change' then
    if event.focused == self.grid then
      if not self.paused then
        self:emit({ type = 'toggle' })
      end
    end

  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

function page.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)

  local function tovalue(s)
    if type(s) == 'table' then
      return 'table'
    end
    return s
  end

  for k,v in pairs(row) do
    row[k] = tovalue(v)
  end

  return row
end

function page.grid:draw()
  self:adjustWidth()
  UI.Grid.draw(self)
end

Event.addRoutine(function()

  while true do
    local e = { os.pullEvent() }
    if not page.paused and not page.filtered[e[1]] then
      table.insert(page.grid.values, 1, {
        event = e[1],
        p1 = e[2],
        p2 = e[3],
        p3 = e[4],
        p4 = e[5],
        p5 = e[6],
      })
      if #page.grid.values > page.grid.height - 1 then
        table.remove(page.grid.values, #page.grid.values)
      end
      page.grid:update()
      page.grid:draw()
      page:sync()
    end
  end
end)

UI:setPage(page)
UI:pullEvents()

require = requireInjector(getfenv(1))
local Event = require('event')
local UI = require('ui')

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

function page.grid:draw()
  self:adjustWidth()
  UI.Grid.draw(self)
end

function eventLoop()

  local function tovalue(s)
    if type(s) == 'table' then
      return 'table'
    end
    return s
  end

  while true do
    local e = { os.pullEvent() }
    if not page.paused and not page.filtered[e[1]] then
      table.insert(page.grid.values, 1, {
        event = e[1],
        p1 = tovalue(e[2]),
        p2 = tovalue(e[3]),
        p3 = tovalue(e[4]),
        p4 = tovalue(e[5]),
        p5 = tovalue(e[6]),
      })
      if #page.grid.values > page.grid.height - 1 then
        table.remove(page.grid.values, #page.grid.values)
      end
      page.grid:update()
      page.grid:draw()
      page:sync()
    end
  end
end

UI:setPage(page)
Event.pullEvents(eventLoop)
UI.term:reset()

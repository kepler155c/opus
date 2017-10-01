requireInjector(getfenv(1))

local Event = require('event')
local UI    = require('ui')

multishell.setTitle(multishell.getCurrent(), 'Help')
UI:configure('Help', ...)

local files = { }
for _,f in pairs(help.topics()) do
  table.insert(files, { name = f })
end

local page = UI.Page {
  labelText = UI.Text {
    x = 3, y = 2,
    value = 'Search',
  },
  filter = UI.TextEntry {
    x = 10, y = 2, ex = -3,
    limit = 32,
  },
  grid = UI.ScrollingGrid {
    y = 4,
    values = files,
    columns = {
      { heading = 'Name', key = 'name' },
    },
    sortColumn = 'name',
  },
  accelerators = {
    q     = 'quit',
    enter = 'grid_select',
  },
}

local function showHelp(name)
  UI.term:reset()
  shell.run('help ' .. name)
  print('Press enter to return')
  repeat
    os.pullEvent('key')
    local _, k = os.pullEvent('key_up')
  until k == keys.enter
end

function page:eventHandler(event)

  if event.type == 'quit' then
    Event.exitPullEvents()

  elseif event.type == 'grid_select' then
    if self.grid:getSelected() then
      showHelp(self.grid:getSelected().name)
      self:setFocus(self.filter)
      self:draw()
    end

  elseif event.type == 'text_change' then
    local text = event.text
    if #text == 0 then
      self.grid.values = files
    else
      self.grid.values = { }
      for _,f in pairs(files) do
        if string.find(f.name, text) then
          table.insert(self.grid.values, f)
        end
      end
    end
    self.grid:update()
    self.grid:setIndex(1)
    self.grid:draw()
  else
    UI.Page.eventHandler(self, event)
  end
end

UI:setPage(page)
UI:pullEvents()

require = requireInjector(getfenv(1))
local Event = require('event')
local UI = require('ui')

multishell.setTitle(multishell.getCurrent(), 'Help')
UI:configure('Help', ...)

local files = { }
for _,f in pairs(fs.list('/rom/help')) do
  table.insert(files, { name = f })
end

local page = UI.Page({
  labelText = UI.Text({
    y = 2,
    x = 3,
    value = 'Search',
  }),
  filter = UI.TextEntry({
    y = 2,
    x = 10,
    width = UI.term.width - 13,
    limit = 32,
  }),
  grid = UI.ScrollingGrid({
    y = 4,
    height = UI.term.height - 4,
    values = files,
    columns = {
      { heading = 'Name', key = 'name', width = 12 },
    },
    sortColumn = 'name',
  }),
  statusBar = UI.StatusBar(),
  accelerators = {
    q = 'quit',
  },
})

local function showHelp(name)
  UI.term:reset()
  shell.run('help ' .. name)
  print('Press enter to return')
  read()
end

function page:eventHandler(event)

  if event.type == 'quit' then
    Event.exitPullEvents()

  elseif event.type == 'key' and event.key == 'enter' then
    if self.grid:getSelected() then
      showHelp(self.grid:getSelected().name)
      self:setFocus(self.filter)
      self:draw()
    end

  elseif event.type == 'grid_select' then
    showHelp(event.selected.name)
    self:setFocus(self.filter)
    self:draw()

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

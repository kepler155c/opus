requireInjector(getfenv(1))

local Config = require('config')
local Event  = require('event')
local UI     = require('ui')
local Util   = require('util')

multishell.setTitle(multishell.getCurrent(), 'System')
UI:configure('System', ...)

local env = {
  path = shell.path(),
  aliases = shell.aliases(),
  lua_path = LUA_PATH,
}
Config.load('shell', env)

UI.TextEntry.defaults.backgroundFocusColor = colors.black

local systemPage = UI.Page {
  backgroundColor = colors.cyan,
  tabs = UI.Tabs {
    pathTab = UI.Window {
      tabTitle = 'Path',
      entry = UI.TextEntry {
        x = 2, y = 2, rex = -2,
        limit = 256,
        value = shell.path(),
        shadowText = 'enter system path',
        accelerators = {
          enter = 'update_path',
        },
      },
      grid = UI.Grid {
        y = 4,
        values = paths,
        disableHeader = true,
        columns = { { key = 'value' } },
        autospace = true,
      },
    },

    aliasTab = UI.Window {
      tabTitle = 'Aliases',
      alias = UI.TextEntry {
        x = 2, y = 2, rex = -2, 
        limit = 32,
        shadowText = 'Alias',
      },
      path = UI.TextEntry {
        y = 3, x = 2, rex = -2,
        limit = 256,
        shadowText = 'Program path',
        accelerators = {
          enter = 'new_alias',
        },
      },
      grid = UI.Grid {
        y = 5,
        values = aliases,
        autospace = true,
        sortColumn = 'alias',
        columns = {
          { heading = 'Alias',   key = 'alias' },
          { heading = 'Program', key = 'path'  },
        },
        accelerators = {
          delete = 'delete_alias',
        },
      },
    },

    infoTab = UI.Window {
      tabTitle = 'Info',
      labelText = UI.Text {
        x = 3, y = 2,
        value = 'Label'
      },
      label = UI.TextEntry {
        x = 9, y = 2, rex = -4,
        limit = 32,
        value = os.getComputerLabel(),
        backgroundFocusColor = colors.black,
        accelerators = {
          enter = 'update_label',
        },
      },
      grid = UI.ScrollingGrid {
        y = 3,
        values = {
          { name = '',  value = ''                  },
          { name = 'CC version',  value = Util.getVersion()                  },
          { name = 'Lua version', value = _VERSION                           },
          { name = 'MC version',  value = _MC_VERSION or 'unknown'           },
          { name = 'Disk free',   value = Util.toBytes(fs.getFreeSpace('/')) },
          { name = 'Computer ID', value = tostring(os.getComputerID())       },
          { name = 'Day',         value = tostring(os.day())                 },
        },
        selectable = false,
        --backgroundColor = colors.blue,
        columns = {
          { key = 'name',  width = 12                 },
          { key = 'value', width = UI.term.width - 15 },
        },
      },
    },
  },
  notification = UI.Notification(),
  accelerators = {
    q = 'quit',
  },
}

function systemPage.tabs.pathTab.grid:draw()
  self.values = { }
  for _,v in ipairs(Util.split(env.path, '(.-):')) do
    table.insert(self.values, { value = v })
  end
  self:update()
  UI.Grid.draw(self)
end

function systemPage.tabs.pathTab:eventHandler(event)

  if event.type == 'update_path' then
    env.path = self.entry.value
    self.grid:setIndex(self.grid:getIndex())
    self.grid:draw()
    Config.update('shell', env)
    systemPage.notification:success('reboot to take effect')
    return true
  end
end

function systemPage.tabs.aliasTab.grid:draw()
  self.values = { }
  local aliases = { }
  for k,v in pairs(env.aliases) do
    table.insert(self.values, { alias = k, path = v })
  end
  self:update()
  UI.Grid.draw(self)
end

function systemPage.tabs.aliasTab:eventHandler(event)

  if event.type == 'delete_alias' then
    env.aliases[self.grid:getSelected().alias] = nil
    self.grid:setIndex(self.grid:getIndex())
    self.grid:draw()
    Config.update('shell', env)
    systemPage.notification:success('reboot to take effect')
    return true

  elseif event.type == 'new_alias' then
    env.aliases[self.alias.value] = self.path.value
    self.alias:reset()
    self.path:reset()
    self:draw()
    self:setFocus(self.alias)
    Config.update('shell', env)
    systemPage.notification:success('reboot to take effect')
    return true
  end
end

function systemPage.tabs.infoTab:eventHandler(event)
  if event.type == 'update_label' then
    os.setComputerLabel(self.label.value)
    systemPage.notification:success('Label updated')
    return true
  end
end

function systemPage:eventHandler(event)

  if event.type == 'quit' then
    Event.exitPullEvents()
  elseif event.type == 'tab_activate' then
    event.activated:focusFirst()
  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

UI:setPage(systemPage)
Event.pullEvents()
UI.term:reset()

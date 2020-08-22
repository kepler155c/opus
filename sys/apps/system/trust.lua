local UI   = require("opus.ui")
local Util = require("opus.util")
local SHA  = require('opus.crypto.sha2')

local function split(s)
  local b = ""
  for i = 1, #s, 5 do
    b = b .. s:sub(i, i+4)
    if i ~= #s-4 then
      b = b .. "-"
    end
  end
  return b
end

return UI.Tab {
  title = 'Trust',
  description = 'Manage trusted devices',
  grid = UI.Grid {
    x = 2, y = 2, ex = -2, ey = -3,
    autospace = true,
    sortColumn = 'id',
    columns = {
      { heading = 'Computer ID', key = 'id'},
      { heading = 'Identity', key = 'pkey'}
    }
  },
  statusBar = UI.StatusBar { values = 'double-click to revoke trust' },
  reload = function(self)
    local values = {}
    for k,v in pairs(Util.readTable('usr/.known_hosts') or {}) do
      table.insert(values, {
        id = k,
        pkey = split(SHA.compute(v):sub(-20):upper()) -- Obfuscate private key for visual ident
      })
    end
    self.grid:setValues(values)
    self.grid:setIndex(1)
  end,
  enable = function(self)
    self:reload()
    UI.Tab.enable(self)
  end,
  eventHandler = function(self, event)
    if event.type == 'grid_select' then
      local hosts = Util.readTable('usr/.known_hosts')
      hosts[event.selected.id] = nil
      Util.writeTable('usr/.known_hosts', hosts)
      self:reload()
    else
      return UI.Tab.eventHandler(self, event)
    end
    return true
  end
}
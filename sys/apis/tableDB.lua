local class = require('class')
local Util  = require('util')

local TableDB = class()
function TableDB:init(args)
  local defaults = {
    fileName = '',
    dirty = false,
    data = { },
    tabledef = { },
  }
  Util.merge(defaults, args)
  Util.merge(self, defaults)
end
 
function TableDB:load()
  local table = Util.readTable(self.fileName)
  if table then
    self.data = table.data
    self.tabledef = table.tabledef
  end
end
 
function TableDB:add(key, entry)
  if type(key) == 'table' then
    key = table.concat(key, ':')
  end
  self.data[key] = entry
  self.dirty = true
end
 
function TableDB:get(key)
  if type(key) == 'table' then
    key = table.concat(key, ':')
  end
  return self.data[key]
end
 
function TableDB:remove(key)
  self.data[key] = nil
  self.dirty = true
end
 
function TableDB:flush()
  if self.dirty then
    Util.writeTable(self.fileName, {
      -- tabledef = self.tabledef,
      data = self.data,
    })
    self.dirty = false
  end
end

return TableDB

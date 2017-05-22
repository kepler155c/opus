local class = require('class')
local Logger = require('logger')
local Peripheral = require('peripheral')

local MEProvider = class()

function MEProvider:init(args)
  local defaults = {
    items = { },
    name = 'ME',
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  if self.side then
    local mep = peripheral.wrap('bottom')
    if mep then
      Util.merge(self, mep)
    end
  else
    local mep = Peripheral.getByMethod('getAvailableItems')
    if mep then
      Util.merge(self, mep)
    end
  end

  if self.side then
    local sides = {
      top = 'down',
      bottom = 'up',
    }
    self.oside = sides[self.side]
  end
end
 
function MEProvider:isValid()
  return self.getAvailableItems and self.getAvailableItems()
end

-- Strip off color prefix
local function safeString(text)

  local val = text:byte(1)

  if val < 32 or val > 128 then

    local newText = {}
    for i = 4, #text do
      local val = text:byte(i)
      newText[i - 3] = (val > 31 and val < 127) and val or 63
    end
    return string.char(unpack(newText))
  end

  return text
end

function MEProvider:refresh()
  self.items = self.getAvailableItems('all')
  for _,v in pairs(self.items) do
    Util.merge(v, v.item)
    v.name = safeString(v.display_name)
  end
  return self.items
end

function MEProvider:listItems()
  self:refresh()
  return self.items
end
 
function MEProvider:getItemInfo(id, dmg)
 
  for key,item in pairs(self.items) do
    if item.id == id and item.dmg == dmg then
      return item
    end
  end
end
 
function MEProvider:craft(id, dmg, qty)

  self:refresh()

  local item = self:getItemInfo(id, dmg)

  if item and item.is_craftable then

    Logger.log('MEProvider', 'requested crafting for: ' .. id .. ':' .. dmg .. ' qty: ' .. qty)
    self.requestCrafting({ id = id, dmg = dmg }, qty)
    return true
  end
end

function MEProvider:craftItems(items)
  local cpus = self.getCraftingCPUs() or { }
  local count = 0

  for _,cpu in pairs(cpus) do
    if cpu.busy then
      return
    end
  end

  for _,item in pairs(items) do
    if count >= #cpus then
      break
    end
    if self:craft(item.id, item.dmg, item.qty) then
      count = count + 1
    end
  end
end

function MEProvider:provide(item, qty, slot)
  return pcall(function()
    self.exportItem({
      id = item.id,
      dmg = item.dmg
    }, self.oside, qty, slot)
  end)
end
 
function MEProvider:insert(slot, qty)
  local s, m = pcall(function() self.pullItem(self.oside, slot, qty) end)
  if not s and m then
    print('MEProvider:pullItem')
    print(m)
    Logger.log('MEProvider', 'Insert failed, trying again')
    sleep(1)
    s, m = pcall(function() self.pullItem('up', slot, qty) end)
    if not s and m then
      print('MEProvider:pullItem')
      print(m)
      Logger.log('MEProvider', 'Insert failed again')
      read()
    else
      Logger.log('MEProvider', 'Insert successful')
    end
  end
end

return MEProvider

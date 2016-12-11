local class = require('class')
local Logger = require('logger')

local MEProvider = class()

function MEProvider:init(args)
  self.items = {}
  self.name = 'ME'
end
 
function MEProvider:isValid()
  local mep = peripheral.wrap('bottom')
  return mep and mep.getAvailableItems and mep.getAvailableItems()
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
  local mep = peripheral.wrap('bottom')
  if mep then
    self.items = mep.getAvailableItems('all')
    for _,v in pairs(self.items) do
      Util.merge(v, v.item)
      v.name = safeString(v.display_name)
    end
  end
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

    local mep = peripheral.wrap('bottom')
    if mep then
      Logger.log('meProvideer', 'requested crafting for: ' .. id .. ':' .. dmg .. ' qty: ' .. qty)
      mep.requestCrafting({ id = id, dmg = dmg }, qty)
      return true
    end
  end

  return false
end

function MEProvider:craftItems(items)
  local mep = peripheral.wrap('bottom')

  local cpus = mep.getCraftingCPUs() or { }
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
  local mep = peripheral.wrap('bottom')
  if mep then
    return pcall(function()
      mep.exportItem({
        id = item.id,
        dmg = item.dmg
      },
      'up',
      qty,
      slot)
    end)

    --if item.qty then
    --  item.qty = item.qty - extractedQty
    --end
  end
end
 
function MEProvider:insert(slot, qty)
  local mep = peripheral.wrap('bottom')
  if mep then
    local s, m = pcall(function() mep.pullItem('up', slot, qty) end)
    if not s and m then
      print('meProvider:pullItem')
      print(m)
      Logger.log('meProvider', 'Insert failed, trying again')
      sleep(1)
      s, m = pcall(function() mep.pullItem('up', slot, qty) end)
      if not s and m then
        print('meProvider:pullItem')
        print(m)
        Logger.log('meProvider', 'Insert failed again')
        read()
      else
        Logger.log('meProvider', 'Insert successful')
      end
    end
  end
end

return MEProvider

local Util = require('util')

local ME = { 
  jobList = { }
}

function ME.setDevice(device)
  ME.p = device
  --Util.merge(ME, ME.p)

  if not device then
    error('ME device not attached')
  end
 
  for k,v in pairs(ME.p) do
    if not ME[k] then
      ME[k] = v
    end
  end
end
 
function ME.isAvailable()
  return not Util.empty(ME.getAvailableItems())
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

function ME.getAvailableItems()
  local items
  pcall(function()
    items = ME.p.getAvailableItems('all')
    for k,v in pairs(items) do
      v.id = v.item.id
      v.name = safeString(v.item.display_name)
      v.qty = v.item.qty
      v.dmg = v.item.dmg
      v.max_dmg = v.item.max_dmg
      v.nbt_hash = v.item.nbt_hash
    end
  end)
 
  return items or { }
end
 
function ME.getItemCount(id, dmg, nbt_hash, ignore_dmg)

  local fingerprint = {  
      id = id,
      nbt_hash = nbt_hash,
  }

  if not ignore_dmg or ignore_dmg ~= 'yes' then
    fingerprint.dmg = dmg or 0
  end

  local item = ME.getItemDetail(fingerprint, false)

  if item then
    return item.qty
  end

  return 0
end
 
function ME.extract(id, dmg, nbt_hash, qty, direction, slot)
  dmg = dmg or 0
  qty = qty or 1
  direction = direction or 'up'
  return pcall(function()
    local fingerprint = {  
        dmg = dmg,
        id = id,
        nbt_hash = nbt_hash
    }
    return ME.exportItem(fingerprint, direction,  qty, slot)
  end)
end
 
function ME.insert(slot, qty, direction)
  direction = direction or 'up'
  return ME.pullItem(direction, slot, qty)
end
 
function ME.isCrafting()
  local cpus = ME.p.getCraftingCPUs() or { }
  for k,v in pairs(cpus) do
    if v.busy then
      return true
    end
  end
end

function ME.isCPUAvailable()
  local cpus = ME.p.getCraftingCPUs() or { }
  local available = false

  for cpu,v in pairs(cpus) do
    if not v.busy then
      available = true
    elseif not ME.jobList[cpu] then -- something else is crafting something (don't know what)
      return false                  -- return false since we are in an unknown state
    end
  end
  return available
end

function ME.getJobList()

  local cpus = ME.p.getCraftingCPUs() or { }
  for cpu,v in pairs(cpus) do
    if not v.busy then
      ME.jobList[cpu] = nil
    end
  end

  return ME.jobList
end

function ME.craft(id, dmg, nbt_hash, qty)
  local cpus = ME.p.getCraftingCPUs() or { }
  for cpu,v in pairs(cpus) do
    if not v.busy then
      ME.p.requestCrafting({
        id = id,
        dmg = dmg or 0,
        nbt_hash = nbt_hash,
        },
        qty or 1,
        cpu
      )

      os.sleep(0) -- tell it to craft, yet it doesn't show busy - try waiting a cycle...
      cpus = ME.p.getCraftingCPUs() or { }
      if not cpus[cpu].busy then
        -- print('sleeping again')
        os.sleep(.1) -- sigh
        cpus = ME.p.getCraftingCPUs() or { }
      end

      -- not working :(
      if cpus[cpu].busy then
        ME.jobList[cpu] = { id = id, dmg = dmg, qty = qty, nbt_hash = nbt_hash }
        return true
      end
      break -- only need to try the first available cpu
    end
  end
  return false
end
 
return ME
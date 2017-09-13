local itemDB = require('itemDB')
local Util   = require('util')

local Craft = { }

local function clearGrid(chestProvider)
  for i = 1, 16 do
    local count = turtle.getItemCount(i)
    if count > 0 then
      chestProvider:insert(i, count)
      if turtle.getItemCount(i) ~= 0 then
        return false
      end
    end
  end
  return true
end

local function splitKey(key)
  local t = Util.split(key, '(.-):')
  local item = { }
  if #t[#t] > 2 then
    item.nbtHash = table.remove(t)
  end
  item.damage = tonumber(table.remove(t))
  item.name = table.concat(t, ':')
  return item
end

local function getItemCount(items, key)
  local item = splitKey(key)
  for _,v in pairs(items) do
    if v.name == item.name and
       v.damage == item.damage and
       v.nbtHash == item.nbtHash then
      return v.count
    end
  end
  return 0
end

local function turtleCraft(recipe, qty, chestProvider)

  clearGrid(chestProvider)

  for k,v in pairs(recipe.ingredients) do
    local item = splitKey(v)
    chestProvider:provide({ id = item.name, dmg = item.damage, nbt_hash = item.nbtHash }, qty, k)
    if turtle.getItemCount(k) == 0 then -- ~= qty then
                                        -- FIX: ingredients cannot be stacked
      return false
    end
  end

  return turtle.craft()
end

function Craft.craftRecipe(recipe, count, chestProvider)

  local items = chestProvider:listItems()

  local function sumItems(items)
    -- produces { ['minecraft:planks:0'] = 8 }
    local t = {}
    for _,item in pairs(items) do
      t[item] = (t[item] or 0) + 1
    end
    return t
  end

  count = math.ceil(count / recipe.count)

  local maxCount = recipe.maxCount or math.floor(64 / recipe.count)
  local summedItems = sumItems(recipe.ingredients)

  for key,icount in pairs(summedItems) do
    local itemCount = getItemCount(items, key)
    if itemCount < icount * count then
      local irecipe = Craft.recipes[key]
      if irecipe then
Util.print('Crafting %d %s', icount * count - itemCount, key)
        if not Craft.craftRecipe(irecipe,
                                 icount * count - itemCount,
                                 chestProvider) then
          turtle.select(1)
          return
        end
      end
    end
  end
  repeat
    if not turtleCraft(recipe, math.min(count, maxCount), chestProvider) then
      turtle.select(1)
      return false
    end
    count = count - maxCount
  until count <= 0

  turtle.select(1)
  return true
end

-- given a certain quantity, return how many of those can be crafted
function Craft.getCraftableAmount(recipe, count, items)

  local function sumItems(recipe, items, summedItems, count)

    local canCraft = 0

    for i = 1, count do
      for _,item in pairs(recipe.ingredients) do
        local summedItem = summedItems[item] or getItemCount(items, item)

        local irecipe = Craft.recipes[item]
        if irecipe and summedItem <= 0 then
          summedItem = summedItem + sumItems(irecipe, items, summedItems, 1)
        end
        if summedItem <= 0 then
          return canCraft
        end
        summedItems[item] = summedItem - 1
      end
      canCraft = canCraft + recipe.count
    end

    return canCraft
  end

  return sumItems(recipe, items, { }, math.ceil(count / recipe.count))
end

function Craft.canCraft(item, count, items)
  return Craft.getCraftableAmount(Craft.recipes[item], count, items) == count
end

function Craft.setRecipes(recipes)
  Craft.recipes = recipes
end

function Craft.getCraftableAmountTest()
  local results = { }
  Craft.setRecipes(Util.readTable('sys/etc/recipes.db'))

  local items = {
    { name = 'minecraft:planks', damage = 0, count = 5 },
    { name = 'minecraft:log',    damage = 0, count = 2 },
  }
  results[1] = { item = 'chest', expected = 1, got = Craft.getCraftableAmount(Craft.recipes['minecraft:chest:0'], 2, items) }

  items = {
    { name = 'minecraft:log',    damage = 0, count = 1 },
    { name = 'minecraft:coal',   damage = 1, count = 1 },
  }
  results[2] = { item = 'torch', expected = 4, got = Craft.getCraftableAmount(Craft.recipes['minecraft:torch:0'], 4, items) }

  return results
end

function Craft.craftRecipeTest(name, count)
  local ChestProvider = require('chestProvider18')
  local chestProvider = ChestProvider({ wrapSide = 'top', direction = 'down' })
  Craft.setRecipes(Util.readTable('usr/etc/recipes.db'))
  return { Craft.craftRecipe(Craft.recipes[name], count, chestProvider) }
end

return Craft

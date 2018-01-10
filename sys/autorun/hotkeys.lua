_G.requireInjector()

local Util = require('util')

local keyboard   = _G.device.keyboard
local multishell = _ENV.multishell

-- overview
keyboard.addHotkey('control-o', function()
  for _,tab in pairs(multishell.getTabs()) do
    if tab.isOverview then
      multishell.setFocus(tab.tabId)
    end
  end
end)

-- restart tab
keyboard.addHotkey('control-backspace', function()
  local tabs = multishell.getTabs()
  local tabId = multishell.getFocus()
  local tab = tabs[tabId]
  if not tab.isOverview then
    multishell.terminate(tabId)
    tab = Util.shallowCopy(tab)
    tab.isDead = false
    tab.focused = true
    multishell.openTab(tab)
  end
end)

-- next tab
keyboard.addHotkey('control-tab', function()
  local tabs = multishell.getTabs()
  local visibleTabs = { }
  local currentTabId = multishell.getFocus()

  local function compareTab(a, b)
    return a.tabId < b.tabId
  end
  for _,tab in Util.spairs(tabs, compareTab) do
    if not tab.hidden then
      table.insert(visibleTabs, tab)
    end
  end

  for k,tab in ipairs(visibleTabs) do
    if tab.tabId == currentTabId then
      if k < #visibleTabs then
        multishell.setFocus(visibleTabs[k + 1].tabId)
        return
      end
    end
  end
  if #visibleTabs > 0 then
    multishell.setFocus(visibleTabs[1].tabId)
  end
end)

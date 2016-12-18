require = requireInjector(getfenv(1))
local Util = require('util')
local UI = require('ui')
local Event = require('event')
local History = require('history')

local sandboxEnv = Util.shallowCopy(getfenv(1))
sandboxEnv.exit = function() Event.exitPullEvents() end
sandboxEnv.require = requireInjector(sandboxEnv)
setmetatable(sandboxEnv, { __index = _G })

multishell.setTitle(multishell.getCurrent(), 'Lua')
UI:configure('Lua', ...)

local command = ''
local history = History.load('.lua_history', 25)

local page = UI.Page({
  menuBar = UI.MenuBar({
    buttons = {
      { text = 'Local',  event = 'local'  },
      { text = 'Global', event = 'global' },
      { text = 'Device', event = 'device' },
    },
  }),
  prompt = UI.TextEntry({
    y = 2,
    shadowText = 'enter command',
    backgroundFocusColor = colors.black,
    limit = 256,
    accelerators = {
      enter            = 'command_enter',
      up               = 'history_back',
      down             = 'history_forward',
      mouse_rightclick = 'clear_prompt',
    },
  }),
  grid = UI.ScrollingGrid({
    y = 3,
    columns = {
      { heading = 'Key',   key = 'name'  },
      { heading = 'Value', key = 'value' },
    },
    sortColumn = 'name',
    autospace = true,
  }),
  notification = UI.Notification(),
})

function page:setPrompt(value, focus)
  self.prompt:setValue(value)
  self.prompt.scroll = 0
  self.prompt:setPosition(#value)
  self.prompt:updateScroll()

  if value:sub(-1) == ')' then
    self.prompt:setPosition(#value - 1)
  end

  self.prompt:draw()
  if focus then
    page:setFocus(self.prompt)
  end
end

function page:enable()
  self:setFocus(self.prompt)
  UI.Page.enable(self)
end

function page:eventHandler(event)

  if event.type == 'global' then
    page:setPrompt('', true)
    self:executeStatement('getfenv(0)')
    command = nil

  elseif event.type == 'local' then
    page:setPrompt('', true)
    self:executeStatement('getfenv(1)')
    command = nil

  elseif event.type == 'device' then
    page:setPrompt('device', true)
    self:executeStatement('device')

  elseif event.type == 'history_back' then
    local value = history.back()
    if value then
      self:setPrompt(value)
    end

  elseif event.type == 'history_forward' then
    self:setPrompt(history.forward() or '')

  elseif event.type == 'clear_prompt' then
    self:setPrompt('')
    history.setPosition(#history.entries + 1)

  elseif event.type == 'command_enter' then
    local s = tostring(self.prompt.value)

    if #s > 0 then
      history.add(s)
      self:executeStatement(s)
    else
      local t = { }
      for k = #history.entries, 1, -1 do
        table.insert(t, {
          name = #t + 1,
          value = history.entries[k],
          isHistory = true,
          pos = k,
        })
      end
      history.setPosition(#history.entries + 1)
      command = nil
      self.grid:setValues(t)
      self.grid:setIndex(1)
      self.grid:adjustWidth()
      self:draw()
    end
    return true

  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

function page:setResult(result)
  local t = { }

  local function safeValue(v)
    local t = type(v)
    if t == 'string' or t == 'number' then
      return v
    end
    return tostring(v)
  end

  if type(result) == 'table' then
    for k,v in pairs(result) do
      local entry = {
        name = safeValue(k),
        rawName = k,
        value = safeValue(v),
        rawValue = v,
      }
      if type(v) == 'table' then
        if Util.size(v) == 0 then
          entry.value = 'table: (empty)'
        else 
          entry.value = 'table'
        end
      end
      table.insert(t, entry)
    end
  else
    table.insert(t, {
      name = type(result),
      value = tostring(result),
      rawValue = result,
    })
  end
  self.grid:setValues(t)
  self.grid:setIndex(1)
  self.grid:adjustWidth()
  self:draw()
end

function page.grid:eventHandler(event)

  local entry = self:getSelected()

  local function commandAppend()
    if entry.isHistory then
      history.setPosition(entry.pos)
      return entry.value
    end
    if type(entry.rawValue) == 'function' then
      if command then
         return command .. '.' .. entry.name .. '()'
      end
      return entry.name .. '()'
    end
    if command then
      if type(entry.rawName) == 'number' then
        return command .. '[' .. entry.name .. ']'
      end
      if entry.name:match("%W") or 
         entry.name:sub(1, 1):match("%d") then
        return command .. "['" .. tostring(entry.name) .. "']"
      end
      return command .. '.' .. entry.name
    end
    return entry.name
  end

  if event.type == 'grid_focus_row' then
    if self.focused then
      page:setPrompt(commandAppend())
    end
  elseif event.type == 'grid_select' then
    page:setPrompt(commandAppend(), true)
    page:executeStatement(commandAppend())
  else
    return UI.Grid.eventHandler(self, event)
  end
  return true
end

function page:rawExecute(s)

  local fn, m = loadstring("return (" .. s .. ')', 'lua')
  if not fn then
    fn, m = loadstring(s, 'lua')
  end

  if fn then
    setfenv(fn, sandboxEnv)
    fn, m = pcall(fn)
  end

  return fn, m
end

function page:executeStatement(statement)

  command = statement

  local s, m = self:rawExecute(command)

  if s and m then
    self:setResult(m)
  else
    self.grid:setValues({ })
    self.grid:draw()
    if m then
      self.notification:error(m, 5)
    end
  end
end

sandboxEnv.args = { ... }
if sandboxEnv.args[1] then
  command = 'args[1]'
  page:setResult(sandboxEnv.args[1])
end

UI:setPage(page)
Event.pullEvents()
UI.term:reset()

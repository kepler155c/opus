require = requireInjector(getfenv(1))
local Util = require('util')
local Event = require('event')
local UI = require('ui')

local cleanEnv = Util.shallowCopy(getfenv(1))
cleanEnv.require = nil

multishell.setTitle(multishell.getCurrent(), 'Files')
UI:configure('Files', ...)

local copied = { }
local marked = { }
local directories = { }
local hidden = true
local cutMode = false

function formatSize(size)
  if size >= 1000000 then
    return string.format('%dM', math.floor(size/1000000, 2))
  elseif size >= 1000 then
    return string.format('%dK', math.floor(size/1000, 2))
  end
  return size
end

local Browser = UI.Page {
  menuBar = UI.MenuBar {
    buttons = {
      { text = '^-',   event = 'updir'                           },
      { text = 'File', event = 'dropdown', dropdown = 'fileMenu' },
      { text = 'Edit', event = 'dropdown', dropdown = 'editMenu' },
      { text = 'View', event = 'dropdown', dropdown = 'viewMenu' },
    },
  },
  fileMenu = UI.DropMenu {
    buttons = {
      { text = 'Run',          event = 'run'     },
      { text = 'Edit    e',    event = 'edit'    },
      { text = 'Shell   s',    event = 'shell'   },
      { text = 'Quit    q',    event = 'quit'    },
    }
  },
  editMenu = UI.DropMenu {
    buttons = {
      { text = 'Mark        m', event = 'mark'   },
      { text = 'Cut        ^x', event = 'cut'    },
      { text = 'Copy       ^c', event = 'copy'   },
      { text = 'Paste      ^v', event = 'paste'  },
      { text = 'Delete    del', event = 'delete' },
      { text = 'Unmark all  u', event = 'unmark' },
    }
  },
  viewMenu = UI.DropMenu {
    buttons = {
      { text = 'Refresh   r',   event = 'refresh'       },
      { text = 'Hidden   ^h',   event = 'toggle_hidden' },
    }
  },
  grid = UI.ScrollingGrid {
    columns = { 
      { heading = 'Name', key = 'name',  width = UI.term.width-11 },
      {                   key = 'flags', width = 2                },
      { heading = 'Size', key = 'fsize', width = 6                },
    },  
    sortColumn = 'name',
    y = 2,
    height = UI.term.height-2,
  },
  statusBar = UI.StatusBar {
    columns = { 
      { '',       'status',    UI.term.width - 19 },
      { '',       'info',      10                 },
      { 'Size: ', 'totalSize', 8                  },
    },
  },
  accelerators = {
    q               = 'quit',
    e               = 'edit',
    s               = 'shell',
    r               = 'refresh',
    space           = 'mark',
    backspace       = 'updir',
    m               = 'move',
    u               = 'unmark',
    d               = 'delete',
    delete          = 'delete',
    [ 'control-h' ] = 'toggle_hidden',
    [ 'control-x' ] = 'cut',
    [ 'control-c' ] = 'copy',
    paste           = 'paste',
  },
}

function Browser:enable()
  UI.Page.enable(self)
  self:setFocus(self.grid)
end

function Browser.grid:sortCompare(a, b)
  if self.sortColumn == 'fsize' then
    return a.size < b.size
  elseif self.sortColumn == 'flags' then
    return a.flags < b.flags
  end
  if a.isDir == b.isDir then
    return a.name:lower() < b.name:lower()
  end
  return a.isDir
end

function Browser.grid:getRowTextColor(file, selected)
  if file.marked then
    return colors.green
  end
  if file.isDir then
    return colors.cyan
  end
  if file.isReadOnly then
    return colors.pink
  end
  return colors.white
end

function Browser.grid:getRowBackgroundColorX(file, selected)
  if selected then
    return colors.gray
  end
  return self.backgroundColor
end

function Browser.statusBar:draw()
  if self.parent.dir then
    local info = '#:' .. Util.size(self.parent.dir.files)
    local numMarked = Util.size(marked)
    if numMarked > 0 then
      info = info .. ' M:' .. numMarked
    end
    self:setValue('info', info)
    self:setValue('totalSize', formatSize(self.parent.dir.totalSize))
    UI.StatusBar.draw(self)
  end
end

function Browser:setStatus(status, ...)
  self.statusBar:timedStatus(string.format(status, ...))
end

function Browser:unmarkAll()
  for k,m in pairs(marked) do
    m.marked = false
  end
  Util.clear(marked)
end

function Browser:getDirectory(directory)
  
  local s, dir = pcall(function()

    local dir = directories[directory]
    if not dir then
      dir = {
        name = directory,
        size = 0,
        files = { },
        totalSize = 0,
        index = 1
      }
      directories[directory] = dir
    end

    self:updateDirectory(dir)

    return dir
  end)

  return s, dir
end

function Browser:updateDirectory(dir)

  dir.size = 0
  dir.totalSize = 0
  Util.clear(dir.files)

  local files = fs.list(dir.name, true)
  if files then
    dir.size = #files
    for _, file in pairs(files) do
      file.fullName = fs.combine(dir.name, file.name)
      file.directory = directory
      file.flags = ''
      if not file.isDir then
        dir.totalSize = dir.totalSize + file.size
        file.fsize = formatSize(file.size)
      else
        file.flags = 'D'
      end
      if file.isReadOnly then
        file.flags = file.flags .. 'R'
      end
      if not hidden or file.name:sub(1, 1) ~= '.' then
        dir.files[file.fullName] = file
      end
    end
  end
--  self.grid:update()
--  self.grid:setIndex(dir.index)
  self.grid:setValues(dir.files)
end

function Browser:setDir(dirName, noStatus)

  self:unmarkAll()

  if self.dir then
    self.dir.index = self.grid:getIndex()
  end
  DIR = fs.combine('', dirName)
  shell.setDir(DIR)
  local s, dir = self:getDirectory(DIR)
  if s then
    self.dir = dir
  elseif noStatus then
    error(dir)
  else
    self:setStatus(dir)
    self:setDir('', true)
    return
  end

  if not noStatus then
    self.statusBar:setValue('status', '/' .. self.dir.name)
    self.statusBar:draw()
  end
  self.grid:setIndex(self.dir.index)
end

function Browser:run(path, ...)
  local tabId = multishell.launch(cleanEnv, path, ...)
  multishell.setFocus(tabId)
end

function Browser:hasMarked()
  if Util.size(marked) == 0 then
    local file = self.grid:getSelected()
    if file then
      file.marked = true
      marked[file.fullName] = file
      self.grid:draw()
    end
  end
  return Util.size(marked) > 0
end

function Browser:eventHandler(event)
  local file = self.grid:getSelected()

  if event.type == 'quit' then
    Event.exitPullEvents()

  elseif event.type == 'edit' and file then
    self:run('/apps/shell', 'edit', file.name)

  elseif event.type == 'shell' then
    self:run('/apps/shell')

  elseif event.type == 'refresh' then
    self:updateDirectory(self.dir)
    self.grid:draw()
    self:setStatus('Refreshed')

  elseif event.type == 'toggle_hidden' then
    hidden = not hidden
    self:updateDirectory(self.dir)
    self.grid:draw()
    if hidden then
      self:setStatus('Hiding hidden')
    else
      self:setStatus('Displaying hidden')
    end

  elseif event.type == 'mark' and file then
    file.marked = not file.marked
    if file.marked then
      marked[file.fullName] = file
    else
      marked[file.fullName] = nil
    end
    self.grid:draw()
    self.statusBar:draw()

  elseif event.type == 'unmark' then
    self:unmarkAll()
    self.grid:draw()
    self:setStatus('Marked files cleared')

  elseif event.type == 'grid_select' or event.type == 'run' then
    if file then
      if file.isDir then
        self:setDir(file.fullName)
      else
        self:run('/apps/shell', file.name)
      end
    end

  elseif event.type == 'updir' then
    local dir = (self.dir.name:match("(.*/)"))
    self:setDir(dir or '/')

  elseif event.type == 'delete' then
    if self:hasMarked() then
      local width = self.statusBar:getColumnWidth('status')
      self.statusBar:setColumnWidth('status', UI.term.width)
      self.statusBar:setValue('status', 'Delete marked? (y/n)')
      self.statusBar:draw()
      self.statusBar:sync()
      local _, ch = os.pullEvent('char')
      if ch == 'y' or ch == 'Y' then
        for k,m in pairs(marked) do
          pcall(function()
            fs.delete(m.fullName)
          end)
        end
      end
      marked = { }
      self.statusBar:setColumnWidth('status', width)
      self.statusBar:setValue('status', '/' .. self.dir.name)
      self:updateDirectory(self.dir)

      self.statusBar:draw()
      self.grid:draw()
      self:setFocus(self.grid)
    end

  elseif event.type == 'copy' or event.type == 'cut' then
    if self:hasMarked() then
      cutMode = event.type == 'cut'
      Util.clear(copied)
      Util.merge(copied, marked)
      --self:unmarkAll()
      self.grid:draw()
      self:setStatus('Copied %d file(s)', Util.size(copied))
    end

  elseif event.type == 'paste' then
    for k,m in pairs(copied) do
      local s, m = pcall(function()
        if cutMode then
          fs.move(m.fullName, fs.combine(self.dir.name, m.name))
        else
          fs.copy(m.fullName, fs.combine(self.dir.name, m.name))
        end
      end)
    end
    self:updateDirectory(self.dir)
    self.grid:draw()
    self:setStatus('Pasted ' .. Util.size(copied) .. ' file(s)')

  else
    return UI.Page.eventHandler(self, event)
  end
  self:setFocus(self.grid)
  return true
end

--[[-- Startup logic --]]--
local args = { ... }

Browser:setDir(args[1] or shell.dir())

UI:setPage(Browser)

Event.pullEvents()
UI.term:reset()

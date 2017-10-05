local class  = require('class')
local Region = require('ui.region')
local Util   = require('util')

local _srep = string.rep
local _ssub = string.sub

local mapColorToGray = {
  [ colors.white     ] = colors.white,
  [ colors.orange    ] = colors.lightGray,
  [ colors.magenta   ] = colors.lightGray,
  [ colors.lightBlue ] = colors.lightGray,
  [ colors.yellow    ] = colors.lightGray,
  [ colors.lime      ] = colors.lightGray,
  [ colors.pink      ] = colors.lightGray,
  [ colors.gray      ] = colors.gray,
  [ colors.lightGray ] = colors.lightGray,
  [ colors.cyan      ] = colors.lightGray,
  [ colors.purple    ] = colors.gray,
  [ colors.blue      ] = colors.gray,
  [ colors.brown     ] = colors.gray,
  [ colors.green     ] = colors.lightGray,
  [ colors.red       ] = colors.gray,
  [ colors.black     ] = colors.black,
}

local mapColorToPaint = { }
for n = 1, 16 do
  mapColorToPaint[2 ^ (n - 1)] = _ssub("0123456789abcdef", n, n)
end

local mapGrayToPaint = { }
for n = 0, 15 do
  local gs = mapColorToGray[2 ^ n]
  mapGrayToPaint[2 ^ n] = mapColorToPaint[gs]
end

local Canvas = class()
function Canvas:init(args)

  self.x = 1
  self.y = 1
  self.layers = { }

  Util.merge(self, args)

  self.height = self.ey - self.y + 1
  self.width = self.ex - self.x + 1

  self.lines = { }
  for i = 1, self.height do
    self.lines[i] = { }
  end
end

function Canvas:resize(w, h)
  for i = self.height, h do
    self.lines[i] = { }
  end

  while #self.lines > h do
    table.remove(self.lines, #self.lines)
  end

  if w ~= self.width then
    for i = 1, self.height do
      self.lines[i] = { }
    end
  end

  self.ex = self.x + w - 1
  self.ey = self.y + h - 1

  self.width = w
  self.height = h

  self:dirty()
end

function Canvas:colorToPaintColor(c)
  if self.isColor then
    return mapColorToPaint[c]
  end
  return mapGrayToPaint[c]
end

function Canvas:copy()
  local b = Canvas({ x = self.x, y = self.y, ex = self.ex, ey = self.ey })
  for i = 1, self.ey - self.y + 1 do
    b.lines[i].text = self.lines[i].text
    b.lines[i].fg = self.lines[i].fg
    b.lines[i].bg = self.lines[i].bg
  end
  return b
end

function Canvas:addLayer(layer, bg, fg)
  local canvas = Canvas({
    x = layer.x,
    y = layer.y,
    ex = layer.x + layer.width - 1,
    ey = layer.y + layer.height - 1,
    isColor = self.isColor,
  })
  canvas:clear(bg, fg)

  canvas.parent = self
  table.insert(self.layers, canvas)
  return canvas
end

function Canvas:removeLayer()
  for k, layer in pairs(self.parent.layers) do
    if layer == self then
      self:setVisible(false)
      table.remove(self.parent.layers, k)
      break
    end
  end
end

function Canvas:setVisible(visible)
  self.visible = visible
  if not visible then
    self.parent:dirty()
    -- set parent's lines to dirty for each line in self
  end
end

function Canvas:write(x, y, text, bg, fg)
  if bg then
    bg = _srep(self:colorToPaintColor(bg), #text)
  end
  if fg then
    fg = _srep(self:colorToPaintColor(fg), #text)
  end
  self:writeBlit(x, y, text, bg, fg)
end

function Canvas:writeBlit(x, y, text, bg, fg)
  if y > 0 and y <= self.height and x <= self.width then

    local width = #text

    -- fix ffs
    if x < 1 then
      text = _ssub(text, 2 - x)
      if bg then
        bg = _ssub(bg, 2 - x)
      end
      if bg then
        fg = _ssub(fg, 2 - x)
      end
      width = width + x - 1
      x = 1
    end

    if x + width - 1 > self.width then
      text = _ssub(text, 1, self.width - x + 1)
      if bg then
        bg = _ssub(bg, 1, self.width - x + 1)
      end
      if bg then
        fg = _ssub(fg, 1, self.width - x + 1)
      end
      width = #text
    end

    if width > 0 then

      local function replace(sstr, pos, rstr, width)
        if pos == 1 and width == self.width then
          return rstr
        elseif pos == 1 then
          return rstr .. _ssub(sstr, pos+width)
        elseif pos + width > self.width then
          return _ssub(sstr, 1, pos-1) .. rstr
        end
        return _ssub(sstr, 1, pos-1) .. rstr .. _ssub(sstr, pos+width)
      end
 
      local line = self.lines[y]
      line.dirty = true
      line.text = replace(line.text, x, text, width)
      if fg then
        line.fg = replace(line.fg, x, fg, width)
      end
      if bg then
        line.bg = replace(line.bg, x, bg, width)
      end
    end
  end
end

function Canvas:writeLine(y, text, fg, bg)
  self.lines[y].dirty = true
  self.lines[y].text = text
  self.lines[y].fg = fg
  self.lines[y].bg = bg
end

function Canvas:reset()
  self.regions = nil
end

function Canvas:clear(bg, fg)
  local width = self.ex - self.x + 1
  local text = _srep(' ', width)
  fg = _srep(self:colorToPaintColor(fg), width)
  bg = _srep(self:colorToPaintColor(bg), width)
  for i = 1, self.ey - self.y + 1 do
    self:writeLine(i, text, fg, bg)
  end
end

function Canvas:punch(rect)
  if not self.regions then
    self.regions = Region.new(self.x, self.y, self.ex, self.ey)
  end
  self.regions:subRect(rect.x, rect.y, rect.ex, rect.ey)
end

function Canvas:blitClipped(device)
  for _,region in ipairs(self.regions.region) do
    self:blit(device,
      { x = region[1] - self.x + 1,
        y = region[2] - self.y + 1,
        ex = region[3]- self.x + 1, 
        ey = region[4] - self.y + 1 },
      { x = region[1], y = region[2] })
  end
end

function Canvas:redraw(device)
  self:reset()
  if #self.layers > 0 then
    for _,layer in pairs(self.layers) do
      self:punch(layer)
    end
    self:blitClipped(device)
  else
    self:blit(device)
  end
  self:clean()
end

function Canvas:isDirty()
  for _, line in pairs(self.lines) do
    if line.dirty then
      return true
    end
  end
end

function Canvas:dirty()
  for _, line in pairs(self.lines) do
    line.dirty = true
  end
end

function Canvas:clean()
  for y, line in pairs(self.lines) do
    line.dirty = false
  end
end

function Canvas:render(device, layers) --- redrawAll ?
  layers = layers or self.layers
  if #layers > 0 then
    self.regions = Region.new(self.x, self.y, self.ex, self.ey)
    local l = Util.shallowCopy(layers)
    for _, canvas in ipairs(layers) do
      table.remove(l, 1)
      if canvas.visible then
        self:punch(canvas)
        canvas:render(device, l)
      end
    end
    self:blitClipped(device)
    self:reset()
  else
    self:blit(device)
  end
  self:clean()
end

function Canvas:blit(device, src, tgt)
  src = src or { x = 1, y = 1, ex = self.ex - self.x + 1, ey = self.ey - self.y + 1 }
  tgt = tgt or self

  for i = 0, src.ey - src.y do
    local line = self.lines[src.y + i]
    if line and line.dirty then
      local t, fg, bg = line.text, line.fg, line.bg
      if src.x > 1 or src.ex < self.ex then
        t  = _ssub(t, src.x, src.ex)
        fg = _ssub(fg, src.x, src.ex)
        bg = _ssub(bg, src.x, src.ex)
      end
      --if tgt.y + i > self.ey then -- wrong place to do clipping ??
      --  break
      --end
      device.setCursorPos(tgt.x, tgt.y + i)
      device.blit(t, fg, bg)
    end
  end
end

function Canvas.convertWindow(win, parent, x, y)

  local w, h = win.getSize()

  win.canvas = Canvas({
    x  = x,
    y  = y,
    ex = x + w - 1,
    ey = y + h - 1,
    isColor = win.isColor(),
  })

  function win.clear()
    win.canvas:clear(win.getBackgroundColor(), win.getTextColor())
  end

  function win.clearLine()
    local x, y = win.getCursorPos()
    win.canvas:write(1,
      y,
      _srep(' ', win.canvas.width),
      win.getBackgroundColor(),
      win.getTextColor())
  end

  function win.write(str)
    local x, y = win.getCursorPos()
    win.canvas:write(x,
      y,
      str,
      win.getBackgroundColor(),
      win.getTextColor())
  end

  function win.blit(text, fg, bg)
    local x, y = win.getCursorPos()
    win.canvas:writeBlit(x, y, text, bg, fg)
  end

  function win.redraw()
    win.canvas:redraw(parent)
  end

  function win.scroll()
    error('CWin:scroll: not implemented')
  end

  function win.reposition(x, y, width, height)
    win.canvas.x, win.canvas.y = x, y
    win.canvas:resize(width or win.canvas.width, height or win.canvas.height)
  end

  win.clear()
end

return Canvas

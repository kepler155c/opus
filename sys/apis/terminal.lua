local colors = _G.colors
local term   = _G.term
local _gsub  = string.gsub

local Terminal = { }

function Terminal.scrollable(win, parent)
  local w, h = win.getSize()
  local _, ph = parent.getSize()
  local scrollPos = 0
  local scp = win.setCursorPos

  win.setCursorPos = function(x, y)
  _G._p = y
    if y > scrollPos + ph then
      win.scrollTo(y - ph)
    end
    scp(x, y)
  end

  win.scrollUp = function()
    win.scrollTo(scrollPos - 1)
  end

  win.scrollDown = function()
    win.scrollTo(scrollPos + 1)
  end

  win.scrollTo = function(p)
    p = math.min(math.max(p, 0), h - ph)
    if p ~= scrollPos then
      scrollPos = p
      win.reposition(1, -scrollPos + 1, w, h)
    end
  end
end

function Terminal.toGrayscale(ct)
  local scolors = {
    [ colors.white ] = colors.white,
    [ colors.orange ] = colors.lightGray,
    [ colors.magenta ] = colors.lightGray,
    [ colors.lightBlue ] = colors.lightGray,
    [ colors.yellow ] = colors.lightGray,
    [ colors.lime ] = colors.lightGray,
    [ colors.pink ] = colors.lightGray,
    [ colors.gray ] = colors.gray,
    [ colors.lightGray ] = colors.lightGray,
    [ colors.cyan ] = colors.lightGray,
    [ colors.purple ] = colors.gray,
    [ colors.blue ] = colors.gray,
    [ colors.brown ] = colors.gray,
    [ colors.green ] = colors.lightGray,
    [ colors.red ] = colors.gray,
    [ colors.black ] = colors.black,
  }

  local methods = { 'setBackgroundColor', 'setBackgroundColour',
                    'setTextColor', 'setTextColour' }
  for _,v in pairs(methods) do
    local fn = ct[v]
    ct[v] = function(c)
      fn(scolors[c])
    end
  end

  local bcolors = {
    [ '1' ] = '8',
    [ '2' ] = '8',
    [ '3' ] = '8',
    [ '4' ] = '8',
    [ '5' ] = '8',
    [ '6' ] = '8',
    [ '9' ] = '8',
    [ 'a' ] = '7',
    [ 'b' ] = '7',
    [ 'c' ] = '7',
    [ 'd' ] = '8',
    [ 'e' ] = '7',
  }

  local function translate(s)
    if s then
      s = _gsub(s, "%w", bcolors)
    end
    return s
  end

  local fn = ct.blit
  ct.blit = function(text, fg, bg)
    fn(text, translate(fg), translate(bg))
  end
end

function Terminal.getNullTerm(ct)
  local nt = Terminal.copy(ct)

  local methods = { 'blit', 'clear', 'clearLine', 'scroll',
                    'setCursorBlink', 'setCursorPos', 'write' }
  for _,v in pairs(methods) do
    nt[v] = function() end
  end

  return nt
end

function Terminal.copy(it, ot)
  ot = ot or { }
  for k,v in pairs(it) do
    if type(v) == 'function' then
      ot[k] = v
    end
  end
  return ot
end

function Terminal.mirror(ct, dt)
  for k,f in pairs(ct) do
    ct[k] = function(...)
      local ret = { f(...) }
      if dt[k] then
        dt[k](...)
      end
      return table.unpack(ret)
    end
  end
end

function Terminal.readPassword(prompt)
  if prompt then
    term.write(prompt)
  end
  local fn = term.current().write
  term.current().write = function() end
  local s
  pcall(function() s = _G.read(prompt) end)
  term.current().write = fn

  if s == '' then
    return
  end
  return s
end

return Terminal

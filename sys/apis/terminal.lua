local Terminal = { }

function Terminal.scrollable(ct, size)

  local size = size or 25
  local w, h = ct.getSize()
  local win = window.create(ct, 1, 1, w, h + size, true)
  local oldWin = Util.shallowCopy(win)
  local scrollPos = 0

  local function drawScrollbar(oldPos, newPos)
    local x, y = oldWin.getCursorPos()
    
    local pos = math.floor(oldPos / size * (h - 1))
    oldWin.setCursorPos(w, oldPos + pos + 1)
    oldWin.write(' ')

    pos = math.floor(newPos / size * (h - 1))
    oldWin.setCursorPos(w, newPos + pos + 1)
    oldWin.write('#')
    
    oldWin.setCursorPos(x, y)
  end

  win.setCursorPos = function(x, y)
    oldWin.setCursorPos(x, y)
    if y > scrollPos + h then
      win.scrollTo(y - h)
    elseif y < scrollPos then
      win.scrollTo(y - 2)
    end
  end

  win.scrollUp = function()
    win.scrollTo(scrollPos - 1)
  end

  win.scrollDown = function()
    win.scrollTo(scrollPos + 1)
  end

  win.scrollTo = function(p)
    p = math.min(math.max(p, 0), size)
    if p ~= scrollPos then
      drawScrollbar(scrollPos, p)
      scrollPos = p
      win.reposition(1, -scrollPos + 1)
    end
  end

  win.clear = function()
    oldWin.clear()
    scrollPos = 0
  end

  drawScrollbar(0, 0)

  return win
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
      if scolors[c] then
        fn(scolors[c])
      end
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
      for k,v in pairs(bcolors) do
        s = s:gsub(k, v)
      end
    end
    return s
  end

  local fn = ct.blit
  ct.blit = function(text, fg, bg)
    fn(text, translate(fg), translate(bg))
  end
end

function Terminal.copy(ot)
  local ct = { }
  for k,v in pairs(ot) do
  	if type(v) == 'function' then
  	  ct[k] = v
  	end
  end
  return ct
end

function Terminal.mirror(ct, dt)
  for k,f in pairs(ct) do
    ct[k] = function(...)
      local ret = { f(...) }
      if dt[k] then
	    dt[k](...)
	   end
      return unpack(ret)
    end
  end
end

return Terminal

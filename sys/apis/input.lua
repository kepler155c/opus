local Util = require('util')

local keys = _G.keys
local os   = _G.os

local modifiers = Util.transpose {
  keys.leftCtrl,  keys.rightCtrl,
  keys.leftShift, keys.rightShift,
  --keys.leftAlt,   keys.rightAlt,
}

local input = {
  pressed = { },
}

function input:toCode(code, ch)

  ch = ch or keys.getName(code)
  local result = { }

  if self.pressed[keys.leftCtrl] or self.pressed[keys.rightCtrl] then
    table.insert(result, 'control')
  end

  --if self.pressed[keys.leftAlt] or self.pressed[keys.rightAlt] then
  --  table.insert(result, 'alt')
  --end

  if self.pressed[keys.leftShift] or self.pressed[keys.rightShift] then
    if modifiers[code] or #ch > 1 then
      table.insert(result, 'shift')
    else
      ch = ch:upper()
    end
  end

  if not modifiers[code] then
    table.insert(result, ch)
  end

  return table.concat(result, '-')
end

function input:reset()
  self.pressed = { }
  self.ch = nil
  self.fired = nil

  self.timer = nil
  self.mch = nil
  self.mfired = nil
end

function input:translate(event, code, p1, p2)
  if event == 'key' then
    if p1 then -- key is held down
      if not modifiers[code] then
        self.fired = input:toCode(code, self.ch)
        return self.fired
      end
    else
      self.fired = nil
      self.ch = nil
      self.pressed[code] = true
    end

  elseif event == 'char' then
    self.ch = code
    -- reset just in case
    self.pressed[keys.leftCtrl] = nil
    self.pressed[keys.rightCtrl] = nil

  elseif event == 'key_up' then
    if not self.fired then
      if self.pressed[code] then
        self.fired = input:toCode(code, self.ch)
        self.pressed[code] = nil
        return self.fired
      end
    end
    self.pressed[code] = nil

  elseif event == 'paste' then
    self.ch = 'paste'
    self.pressed[keys.leftCtrl] = nil
    self.pressed[keys.rightCtrl] = nil
    self.fired = input:toCode(0, self.ch)
    return self.fired

  elseif event == 'mouse_click' then
    local buttons = { 'mouse_click', 'mouse_rightclick' }
    self.mch = buttons[code]
    self.mfired = nil

  elseif event == 'mouse_drag' then
    self.mch = 'mouse_drag'
    self.mfired = input:toCode(0, self.mch)
    return self.mfired

  elseif event == 'mouse_up' then
    if not self.mfired then
      local clock = os.clock()
      if self.timer and
         p1 == self.x and p2 == self.y and
         (clock - self.timer < .5) then

        self.mch = 'mouse_doubleclick'
        self.timer = nil
      else
        self.timer = os.clock()
        self.x = p1
        self.y = p2
      end
      self.mfired = input:toCode(0, self.mch)
    else
      self.mch = 'mouse_up'
      self.mfired = input:toCode(0, self.mch)
    end
    return self.mfired

  elseif event == "mouse_scroll" then
    local directions = {
      [ -1 ] = 'scrollUp',
      [  1 ] = 'scrollDown'
    }
    self.mch = directions[code]
    return input:toCode(0, self.mch)
  end
end

function input:test()
  while true do
    local ch = self:translate(os.pullEvent())
    if ch then
      print('GOT: ' .. ch)
    end
  end
end

return input

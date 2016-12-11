local input = { }

function input:translate(event, code)

  if event == 'key' then
    local ch = keys.getName(code)
    if ch then

      if code == keys.leftCtrl or code == keys.rightCtrl then
        self.control = true
        self.combo = false
        return
      end

      if code == keys.leftShift or code == keys.rightShift  then
        self.shift = true
        self.combo = false
        return
      end

      if self.shift then
        if #ch > 1 then
          ch = 'shift-' .. ch
        elseif self.control then
          -- will create control-X
          -- better than shift-control-x
          ch = ch:upper()
        end
        self.combo = true
      end

      if self.control then
        ch = 'control-' .. ch
        self.combo = true
        -- even return numbers such as
        -- control-seven
        return ch
      end

      -- filter out characters that will be processed in
      -- the subsequent char event
      if ch and #ch > 1 and (code < 2 or code > 11) then
        return ch
      end
    end

  elseif event == 'key_up' then

    if code == keys.leftCtrl or code == keys.rightCtrl then
      self.control = false
    elseif code == keys.leftShift or code == keys.rightShift then
      self.shift = false
    else
      return
    end

    -- only send through the shift / control event if it wasn't
    -- used in combination with another event
    if not self.combo then
      return keys.getName(code)
    end

  elseif event == 'char' then
    if not self.control then
      self.combo = true
      return event
    end

  elseif event == 'mouse_click' then

    local buttons = { 'mouse_click', 'mouse_rightclick', 'mouse_doubleclick' }

    self.combo = true
    if self.shift then
      return 'shift-' .. buttons[code]
    end
    return buttons[code]

  elseif event == "mouse_scroll" then
    local directions = {
      [ -1 ] = 'scrollUp',
      [  1 ] = 'scrollDown'
    }
    return directions[code]

  elseif event == 'paste' then
    self.combo = true
    return event

  elseif event == 'mouse_drag' then
    return event
  end
end

-- can be useful for testing what keys are generated
function input:test()
  print('press a key...')
  while true do
    local e, code = os.pullEvent()

    if e == 'char' and code == 'q' then
      break
    end

    local ch = input:translate(e, code)
    if ch then
      print(e .. ' ' .. code .. ' ' .. ch)
    end
  end
end

return input

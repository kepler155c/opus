local Event     = require('event')
local Terminal  = require('terminal')
local Util      = require('util')

local colors    = _G.colors
local modem     = _G.device.wireless_modem
local term      = _G.term
local textutils = _G.textutils

local terminal = Terminal.window(term.current())
terminal.setMaxScroll(300)
local oldTerm = term.redirect(terminal)

local function syntax()
  error('Syntax: sniff [port]')
end

local port = ({ ... })[1] or syntax()
port = tonumber(port) or syntax()

Event.on('modem_message',
  function(_, _, dport, _, data, _)
    if dport == port then
      terminal.scrollBottom()
      terminal.setTextColor(colors.white)
      print(textutils.serialize(data))
    end
  end)

Event.on('mouse_scroll', function(_, direction)
  if direction == -1 then
    terminal.scrollUp()
  else
    terminal.scrollDown()
  end
end)

local function sniffer(_, _, data)
  terminal.scrollBottom()
  terminal.setTextColor(colors.yellow)
  local ot = term.redirect(terminal)
  print(textutils.serialize(data))
  term.redirect(ot)
end

local socket = _G.transport.sockets[port]
if socket then
  if not socket.sniffers then
    socket.sniffers = { modem.transmit }
    socket.transmit = function(...)
      for _,v in pairs(socket.sniffers) do
        v(...)
      end
    end
  end
  table.insert(socket.sniffers, sniffer)
end

local s, m = pcall(Event.pullEvents)

if socket then
  Util.removeByValue(socket.sniffers, sniffer)
end

term.redirect(oldTerm)

if not s and m then
  error(m)
end

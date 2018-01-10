local kernel     = _G.kernel
local multishell = _ENV.multishell

_G.network = { }

kernel.hook('device_attach', function(_, eventData)
  if eventData[1] == 'wireless_modem' then
    local s, m = multishell.openTab({
      path = 'sys/services/network.lua',
      hidden = true
    })
    if not s and m then
      debug(m)
    end
  end
end)

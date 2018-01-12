local kernel     = _G.kernel

_G.network = { }

kernel.hook('device_attach', function(_, eventData)
  if eventData[1] == 'wireless_modem' then
	  local routine = kernel.newRoutine({
      path = 'sys/services/network.lua',
      hidden = true
    })
    kernel.run(routine)
  end
end)

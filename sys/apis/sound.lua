local peripheral  = _G.peripheral
local speaker     = peripheral.find('speaker')

local Sound = { }

function Sound.play(sound, vol)
	if speaker then
		speaker.playSound('minecraft:' .. sound, vol or 1)
	end
end

return Sound

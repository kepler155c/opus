local peripheral  = _G.peripheral

local Sound = { }

function Sound.play(sound, vol)
	local speaker = peripheral.find('speaker')
	if speaker then
		speaker.playSound('minecraft:' .. sound, vol or 1)
	end
end

return Sound

local peripheral  = _G.peripheral

local Sound = {
	_volume = 1,
}

function Sound.play(sound, vol)
	local speaker = peripheral.find('speaker')
	if speaker then
		speaker.playSound('minecraft:' .. sound, vol or Sound._volume)
	end
end

function Sound.setVolume(volume)
	Sound._volume = math.max(0, math.min(volume, 1))
end

return Sound

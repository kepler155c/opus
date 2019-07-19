local os         = _G.os
local peripheral = _G.peripheral

-- Default label
if not os.getComputerLabel() then
	local id = os.getComputerID()

	if _G.turtle then
		os.setComputerLabel('turtle_' .. id)

	elseif _G.pocket then
		os.setComputerLabel('pocket_' .. id)

	elseif _G.commands then
		os.setComputerLabel('command_' .. id)

	elseif peripheral.find('neuralInterface') then
		os.setComputerLabel('neural_' .. id)

	else
		os.setComputerLabel('computer_' .. id)
	end
end

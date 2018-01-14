-- Default label
if not os.getComputerLabel() then
  showStatus('Setting computer label')

  local id = os.getComputerID()
  if _G.turtle then
    os.setComputerLabel('turtle_' .. id)
  elseif _G.pocket then
    os.setComputerLabel('pocket_' .. id)
  elseif _G.commands then
    os.setComputerLabel('command_' .. id)
  else
    os.setComputerLabel('computer_' .. id)
  end
end

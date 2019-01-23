local multishell = _ENV.multishell
local os         = _G.os
local read       = _G.read
local shell      = _ENV.shell

local args = { ... }
if not args[1] then
  error('Syntax: cedit <filename>')
end

if not _G.cloud_catcher then
  print('Paste key: ')
  local key = read()
  if #key == 0 then
    return
  end
  -- open an unfocused tab
  local id = shell.openTab('cloud ' .. key)
  print('Connecting...')
  while not _G.cloud_catcher do
    os.sleep(.2)
  end
  multishell.setTitle(id, 'Cloud')
end

shell.run('cloud edit ' .. table.unpack({ ... }))

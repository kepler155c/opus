local read  = _G.read
local shell = _ENV.shell

if not _G.http.websocket then
  error('Requires CC: Tweaked')
end

if not _G.cloud_catcher then
  print('Paste key: ')
  local key = read()
  if #key == 0 then
    return
  end
  print('Connecting...')
  shell.run('cloud ' .. key)
end

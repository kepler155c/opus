local fs    = _G.fs
local shell = _ENV.shell

if fs.exists('.opus_upgrade') then
	fs.delete('.opus_upgrade')
	print('Updating packages')
	shell.run('package updateall')
	os.reboot()
end

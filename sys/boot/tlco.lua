local run = os.run
local shutdown = os.shutdown

local args = {...} -- keep the args so that they can be passed to opus.lua

os.run = function() 
	os.run = run
end

os.shutdown = function()
	os.shutdown = shutdown

	_ENV.multishell = nil -- prevent sys/apps/shell.lua erroring for odd reasons

	local success, err = pcall(function()
		run(_ENV, 'sys/boot/opus.lua', table.unpack(args))
	end)
	term.redirect(term.native())
	if success then
		print("Opus OS abruptly stopped.")
	else
		printError("Opus OS errored.")
		printError(err)
	end
	print("Press any key to continue.")
	os.pullEvent("key")
	shutdown()
end

shell.exit()
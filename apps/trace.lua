local args = {...}

if not args[1] then
	print("Usage:")
	print(shell.getRunningProgram() .. " <program> [program arguments, ...]")
	return
end

local path = shell.resolveProgram(args[1]) or shell.resolve(args[1])

-- here be dragons
if fs.exists(path) then
	local eshell = setmetatable({getRunningProgram=function() return path end}, {__index = shell})
	local env = setmetatable({shell=eshell}, {__index=_ENV})
	
	local f = fs.open(path, "r")
	local d = f.readAll()
	f.close()
	
	local func, e = load(d, fs.getName(path), nil, env)
	if not func then
		printError("Syntax error:")
		printError("  " .. e)
	else
		table.remove(args, 1)
		xpcall(function() func(unpack(args)) end, function(err)
			local trace = {}
			local i, hitEnd, _, e = 4, false
			repeat
				_, e = pcall(function() error("<tracemarker>", i) end)
				i = i + 1
				if e == "xpcall: <tracemarker>" then
					hitEnd = true
					break
				end
				table.insert(trace, e)
			until i > 10
			table.remove(trace)
			if err:match("^" .. trace[1]:match("^(.-:%d+)")) then table.remove(trace, 1) end
			printError("\nProgram has crashed! Stack trace:")
			printError(err)
			for i, v in ipairs(trace) do
				printError("  at " .. v:match("^(.-:%d+)"))
			end
			if not hitEnd then
				printError("  ...")
			end
		end)
	end
else
	printError("program not found")
end

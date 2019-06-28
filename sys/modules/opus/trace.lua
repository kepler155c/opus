-- stack trace by SquidDev (MIT License)
-- https://raw.githubusercontent.com/SquidDev-CC/mbs/master/lib/stack_trace.lua

local type = type
local debug_traceback = type(debug) == "table" and type(debug.traceback) == "function" and debug.traceback

local function traceback(x)
	-- Attempt to detect error() and error("xyz", 0).
	-- This probably means they're erroring the program intentionally and so we
	-- shouldn't display anything.
	if x == nil or (type(x) == "string" and not x:find(":%d+:")) then
		return x
	end

	if debug_traceback then
		-- The parens are important, as they prevent a tail call occuring, meaning
		-- the stack level is preserved. This ensures the code behaves identically
		-- on LuaJ and PUC Lua.
		return (debug_traceback(tostring(x), 2))
	else
		local level = 3
		local out = { tostring(x), "stack traceback:" }
		while true do
			local _, msg = pcall(error, "", level)
			if msg == "" then break end

			out[#out + 1] = "  " .. msg
			level = level + 1
		end

		return table.concat(out, "\n")
	end
end

local function trim_traceback(target, marker)
	local ttarget, tmarker = {}, {}
	for line in target:gmatch("([^\n]*)\n?") do ttarget[#ttarget + 1] = line end
	for line in marker:gmatch("([^\n]*)\n?") do tmarker[#tmarker + 1] = line end

	-- Trim identical suffixes
	local t_len, m_len = #ttarget, #tmarker
	while t_len >= 3 and ttarget[t_len] == tmarker[m_len] do
		table.remove(ttarget, t_len)
		t_len, m_len = t_len - 1, m_len - 1
	end

	-- Trim elements from this file and xpcall invocations
	while t_len >= 1 and ttarget[t_len]:find("^\tstack_trace%.lua:%d+:") or
				ttarget[t_len] == "\t[C]: in function 'xpcall'" or ttarget[t_len] == "  xpcall: " do
		table.remove(ttarget, t_len)
		t_len = t_len - 1
	end

	ttarget[#ttarget] = nil -- remove 2 calls added by the added xpcall
	ttarget[#ttarget] = nil

	return ttarget
end

--- Run a function with
return function (fn, ...)
	-- So this is rather grim: we need to get the full traceback and current one and remove
	-- the common prefix
	local trace
	local args = { ... }

	-- xpcall in Lua 5.1 does not accept parameters
	-- which is not ideal
	local res = table.pack(xpcall(function()
		return fn(table.unpack(args))
	end, traceback))

	if not res[1] then 
		trace = traceback("trace.lua:1:")
	end
	local ok, err = res[1], res[2]

	if not ok and err ~= nil then
		trace = trim_traceback(err, trace)

		-- Find the position where the stack traceback actually starts
		local trace_starts
		for i = #trace, 1, -1 do
			if trace[i] == "stack traceback:" then trace_starts = i; break end
		end

		for _, line in pairs(trace) do
			_G._syslog(line)
		end

		-- If this traceback is more than 15 elements long, keep the first 9, last 5
		-- and put an ellipsis between the rest
		local max = 10
		if trace_starts and #trace - trace_starts > max then
			local keep_starts = trace_starts + 7
			for i = #trace - trace_starts - max, 0, -1 do
				table.remove(trace, keep_starts + i)
			end
			table.insert(trace, keep_starts, "  ...")
		end

		for k, line in pairs(trace) do
			trace[k] = line:gsub("in function", " in")
		end

		return false, table.remove(trace, 1), table.concat(trace, "\n")
	end

	return table.unpack(res, 1, res.n)
end

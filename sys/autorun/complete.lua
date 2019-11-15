local fs = _G.fs

local function completeMultipleChoice(sText, tOptions, bAddSpaces)
	local tResults = { }
	for n = 1,#tOptions do
		local sOption = tOptions[n]
		if #sOption + (bAddSpaces and 1 or 0) > #sText and string.sub(sOption, 1, #sText) == sText then
			local sResult = string.sub(sOption, #sText + 1)
			if bAddSpaces then
				table.insert(tResults, sResult .. " ")
			else
				table.insert(tResults, sResult)
			end
		end
	end
	return tResults
end

_ENV.shell.setCompletionFunction("sys/apps/package.lua",
	function(_, index, text)
		if index == 1 then
			return completeMultipleChoice(text, { "install ", "update ", "uninstall ", "updateall ", "refresh" })
		end
	end)

_ENV.shell.setCompletionFunction("sys/apps/inspect.lua",
	function(_, index, text)
		if index == 1 then
			local components = { }
			for _, f in pairs(fs.list('sys/modules/opus/ui/components')) do
				table.insert(components, (f:gsub("%.lua$", "")))
			end
			return completeMultipleChoice(text, components)
		end
	end)

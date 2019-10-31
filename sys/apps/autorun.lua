local Packages = require('opus.packages')

local colors     = _G.colors
local fs         = _G.fs
local keys       = _G.keys
local multishell = _ENV.multishell
local os         = _G.os
local shell      = _ENV.shell
local term       = _G.term

local success = true

local function runDir(directory)
	if not fs.exists(directory) then
		return true
	end

	local files = fs.list(directory)
	table.sort(files)

	for _,file in ipairs(files) do
		os.sleep(0)
		local result, err = shell.run(directory .. '/' .. file)

		if result then
			if term.isColor() then
				term.setTextColor(colors.green)
			end
			term.write('[PASS] ')
			term.setTextColor(colors.white)
			term.write(fs.combine(directory, file))
			print()
		else
			if term.isColor() then
				term.setTextColor(colors.red)
			end
			term.write('[FAIL] ')
			term.setTextColor(colors.white)
			term.write(fs.combine(directory, file))
			if err then
				_G.printError('\n' .. err)
			end
			print()
			success = false
		end
	end
end

runDir('sys/autorun')
for _, package in pairs(Packages:installedSorted()) do
	local packageDir = 'packages/' .. package.name .. '/autorun'
	runDir(packageDir)
end
runDir('usr/autorun')

if not success then
	if multishell then
		multishell.setFocus(multishell.getCurrent())
	end
	_G.printError('A startup program has errored')
	print('Press enter to continue')

	while true do
		local e, code = os.pullEventRaw('key')
		if e == 'terminate' or e == 'key' and code == keys.enter then
			break
		end
	end
end


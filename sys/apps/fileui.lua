local UI   = require('opus.ui')
local Util = require('opus.util')

local shell  = _ENV.shell

-- fileui [--path=path] [--exec=filename]

local page = UI.Page {
	fileselect = UI.FileSelect { },
	eventHandler = function(self, event)
		if event.type == 'select_file' then
			self.selected = event.file
			UI:quit()

		elseif event.type == 'select_cancel' then
			UI:quit()
		end

		return UI.FileSelect.eventHandler(self, event)
	end,
}

local _, args = Util.parse(...)

UI:setPage(page, args.path)
UI:start()
UI.term:setCursorBlink(false)

if args.exec and page.selected then
	shell.openForegroundTab(string.format('%s %s', args.exec, page.selected))
	return
end

-- print('selected: ' .. tostring(selected))
return page.selected

local class = require('opus.class')
local fuzzy = require('opus.fuzzy')
local UI    = require('opus.ui')

local fs      = _G.fs
local _insert = table.insert

UI.QuickSelect = class(UI.Window)
UI.QuickSelect.defaults = {
	UIElement = 'QuickSelect',
}
function UI.QuickSelect:postInit()
	self.filterEntry = UI.TextEntry {
		x = 2, y = 2, ex = -2,
		shadowText = 'File name',
		accelerators = {
			[ 'enter' ] = 'accept',
			[ 'up' ] = 'grid_up',
			[ 'down' ] = 'grid_down',
		},
	}
	self.grid = UI.ScrollingGrid {
		x = 2, y = 3, ex = -2, ey = -4,
		disableHeader = true,
		columns = {
			{ key = 'name' },
			{ key = 'dir', textColor = 'lightGray' },
		},
		accelerators = {
			grid_select = 'accept',
		},
	}
	self.cancel = UI.Button {
		x = -9, y = -2,
		text = 'Cancel',
		event = 'select_cancel',
	}
end

function UI.QuickSelect:draw()
	self:fillArea(1, 1, self.width, self.height, string.rep('\127', self.width), 'black', 'gray')
	self:drawChildren()
end

function UI.QuickSelect:applyFilter(filter)
	if filter then
		filter = filter:lower()
		self.grid.sortColumn = 'score'

		for _,v in pairs(self.grid.values) do
			v.score = -fuzzy(v.lname, filter)
		end
	else
		self.grid.sortColumn = 'lname'
	end

	self.grid:update()
	self.grid:setIndex(1)
end

function UI.QuickSelect.getFiles()
	local t = { }
	local function recurse(dir)
		local files = fs.list(dir)
		for _,f in ipairs(files) do
			local fullName = fs.combine(dir, f)
			if fs.isDir(fullName) then
				-- skip virtual dirs
				if f ~= '.git' and fs.native.isDir(fullName) then
					recurse(fullName)
				end
			else
				_insert(t, {
					name = f,
					dir = dir,
					lname = f:lower(),
					fullName = fullName,
				})
			end
		end
	end
	recurse('')
	return t
end

function UI.QuickSelect:enable()
	self.grid.values = self:getFiles()
	self:applyFilter()
	self.filterEntry:reset()
	UI.Window.enable(self)
end

function UI.QuickSelect:eventHandler(event)
	if event.type == 'grid_up' then
		self.grid:emit({ type = 'scroll_up' })
		return true

	elseif event.type == 'grid_down' then
		self.grid:emit({ type = 'scroll_down' })
		return true

	elseif event.type == 'accept' then
		local sel = self.grid:getSelected()
		if sel then
			self:emit({ type = 'select_file', file = sel.fullName, element = self })
		end
		return true

	elseif event.type == 'text_change' then
		self:applyFilter(event.text)
		self.grid:draw()
		return true

	end
end

local class = require('opus.class')
local UI    = require('opus.ui')
local Util  = require('opus.util')

local fs = _G.fs

UI.FileSelect = class(UI.Window)
UI.FileSelect.defaults = {
	UIElement = 'FileSelect',
}
function UI.FileSelect:postInit()
	self.grid = UI.ScrollingGrid {
		x = 2, y = 2, ex = -2, ey = -4,
		dir = '/',
		sortColumn = 'name',
		columns = {
			{ heading = 'Name', key = 'name' },
			{ heading = 'Size', key = 'size', width = 5 }
		},
		getDisplayValues = function(_, row)
			return {
				name = row.name,
				size = row.size and Util.toBytes(row.size),
			}
		end,
		getRowTextColor = function(_, file)
			return file.isDir and 'cyan' or file.isReadOnly and 'pink' or 'white'
		end,
		sortCompare = function(self, a, b)
			if self.sortColumn == 'size' then
				return a.size < b.size
			end
			if a.isDir == b.isDir then
				return a.name:lower() < b.name:lower()
			end
			return a.isDir
		end,
		draw = function(self)
			local files = fs.listEx(self.dir)
			if #self.dir > 0 then
				table.insert(files, {
					name = '..',
					isDir = true,
				})
			end
			self:setValues(files)
			self:setIndex(1)
			UI.Grid.draw(self)
		end,
	}
	self.path = UI.TextEntry {
		x = 2, y = -2, ex = -11,
		accelerators = {
			enter = 'path_enter',
		}
	}
	self.cancel = UI.Button {
		x = -9, y = -2,
		text = 'Cancel',
		event = 'select_cancel',
	}
end

function UI.FileSelect:draw()
	self:fillArea(1, 1, self.width, self.height, string.rep('\127', self.width), 'black', 'gray')
	self:drawChildren()
end

function UI.FileSelect:enable(path)
	self:setPath(path or '')
	UI.Window.enable(self)
end

function UI.FileSelect:setPath(path)
	self.grid.dir = path
	while not fs.isDir(self.grid.dir) do
		self.grid.dir = fs.getDir(self.grid.dir)
	end
	self.path.value = self.grid.dir
end

function UI.FileSelect:eventHandler(event)
	if event.type == 'grid_select' then
		self.grid.dir = fs.combine(self.grid.dir, event.selected.name)
		self.path.value = self.grid.dir
		if event.selected.isDir then
			self.grid:draw()
			self.path:draw()
		else
			self:emit({ type = 'select_file', file = '/' .. self.path.value, element = self })
		end
		return true

	elseif event.type == 'path_enter' then
		if self.path.value then
			if fs.isDir(self.path.value) then
				self:setPath(self.path.value)
				self.grid:draw()
				self.path:draw()
			else
				self:emit({ type = 'select_file', file = '/' .. self.path.value, element = self })
			end
		end
		return true
	end
end

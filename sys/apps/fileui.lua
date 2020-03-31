local UI   = require('opus.ui')
local Util = require('opus.util')

local colors = _G.colors
local fs     = _G.fs
local shell  = _ENV.shell

local selected

-- fileui [--path=path] [--exec=filename]

local page = UI.Page {
	title = 'Select File',
	-- x = 3, ex = -3, y = 2, ey = -2,
	grid = UI.ScrollingGrid {
		x = 2, y = 2, ex = -2, ey = -4,
		path = '',
		sortColumn = 'name',
		columns = {
			{ heading = 'Name', key = 'name' },
			{ heading = 'Size', key = 'size', width = 5 }
		},
		getDisplayValues = function(_, row)
			if row.size then
				row = Util.shallowCopy(row)
				row.size = Util.toBytes(row.size)
			end
			return row
		end,
		getRowTextColor = function(_, file)
			if file.isDir then
				return colors.cyan
			end
			if file.isReadOnly then
				return colors.pink
			end
			return colors.white
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
	},
	path = UI.TextEntry {
		x  =  2,
		y  = -2,
		ex = -11,
		limit = 256,
		accelerators = {
			enter = 'path_enter',
		}
	},
	cancel = UI.Button {
		text = 'Cancel',
		x = -9,
		y = -2,
		event = 'cancel',
	},
	draw = function(self)
		self:fillArea(1, 1, self.width, self.height, string.rep('\127', self.width), colors.black, colors.gray)
		self:drawChildren()
	end,
}

function page:enable(path)
	self:setPath(path or shell.dir())
	UI.Page.enable(self)
end

function page:setPath(path)
	self.grid.dir = path
	while not fs.isDir(self.grid.dir) do
		self.grid.dir = fs.getDir(self.grid.dir)
	end

	self.path.value = self.grid.dir
end

function page:eventHandler(event)
	if event.type == 'grid_select' then
		self.grid.dir = fs.combine(self.grid.dir, event.selected.name)
		self.path.value = self.grid.dir
		if event.selected.isDir then
			self.grid:draw()
			self.path:draw()
		else
			selected = self.path.value
			UI:quit()
		end

	elseif event.type == 'path_enter' then
		if fs.isDir(self.path.value) then
			self:setPath(self.path.value)
			self.grid:draw()
			self.path:draw()
		else
			selected = self.path.value
			UI:quit()
		end

	elseif event.type == 'cancel' then
		UI:quit()
	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

local _, args = Util.parse(...)

UI:setPage(page, args.path)
UI:start()
UI.term:setCursorBlink(false)

if args.exec and selected then
	shell.openForegroundTab(string.format('%s %s', args.exec, selected))
	return
end

--print('selected: ' .. tostring(selected))
return selected

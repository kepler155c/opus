local Config = require('opus.config')
local Event  = require('opus.event')
local pastebin = require('opus.http.pastebin')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local colors     = _G.colors
local fs         = _G.fs
local multishell = _ENV.multishell
local os         = _G.os
local shell      = _ENV.shell

local FILE    = 1

UI:configure('Files', ...)

local config = Config.load('Files', {
	showHidden = false,
	showDirSizes = false,
})
config.associations = config.associations or {
	nft = 'pain',
}

local copied = { }
local marked = { }
local directories = { }
local cutMode = false

local function formatSize(size)
	if size >= 1000000 then
		return string.format('%dM', math.floor(size/1000000, 2))
	elseif size >= 1000 then
		return string.format('%dK', math.floor(size/1000, 2))
	end
	return size
end

local Browser = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = '^-',   event = 'updir' },
			{ text = 'File', dropdown = {
					{ text = 'Run',               event = 'run',      flags = FILE },
					{ text = 'Edit         e',    event = 'edit',     flags = FILE },
					{ text = 'Cloud edit   c',    event = 'cedit',    flags = FILE },
					{ text = 'Pastebin put p',    event = 'pastebin', flags = FILE },
					{ text = 'Shell        s',    event = 'shell'  },
					{ spacer = true },
					{ text = 'Quit        ^q',    event = 'quit'   },
			} },
			{ text = 'Edit', dropdown = {
					{ text = 'Cut          ^x', event = 'cut'    },
					{ text = 'Copy         ^c', event = 'copy'   },
					{ text = 'Copy path      ', event = 'copy_path' },
					{ text = 'Paste        ^v', event = 'paste'  },
					{ spacer = true },
					{ text = 'Mark          m', event = 'mark'   },
					{ text = 'Unmark all    u', event = 'unmark' },
					{ spacer = true },
					{ text = 'Delete      del', event = 'delete' },
			} },
			{ text = 'View', dropdown = {
					{ text = 'Refresh     r',   event = 'refresh'       },
					{ text = 'Hidden     ^h',   event = 'toggle_hidden' },
					{ text = 'Dir Size   ^s',   event = 'toggle_dirSize' },
			} },
			{ text = '\187',
				x = -3,
				dropdown = {
					{ text = 'Associations', event = 'associate' },
			} },
		},
	},
	grid = UI.ScrollingGrid {
		columns = {
			{ heading = 'Name', key = 'name'             },
			{                   key = 'flags', width = 2 },
			{ heading = 'Size', key = 'fsize', width = 5 },
		},
		sortColumn = 'name',
		y = 2, ey = -2,
	},
	statusBar = UI.StatusBar {
		columns = {
			{ key = 'status'               },
			{ key = 'totalSize', width = 6 },
		},
	},
	notification = UI.Notification { },
	associations = UI.SlideOut {
		backgroundColor = colors.cyan,
		menuBar = UI.MenuBar {
			buttons = {
				{ text = 'Save',    event = 'save'    },
				{ text = 'Cancel',  event = 'cancel'  },
			},
		},
		grid = UI.ScrollingGrid {
			x = 2, ex = -6, y = 3, ey = -5,
			columns = {
				{ heading = 'Extension', key = 'name'  },
				{ heading = 'Program',   key = 'value' },
			},
			autospace = true,
			sortColumn = 'name',
			accelerators = {
				delete = 'remove_entry',
			},
		},
		remove = UI.Button {
			x = -4, y = 6,
			text = '-', event = 'remove_entry', help = 'Remove',
		},
		form = UI.Form {
			x = 3, y = -3, ey = -2,
			margin = 1,
			manualControls = true,
			[1] = UI.TextEntry {
				width = 20,
				formLabel = 'Extension', formKey = 'name',
				shadowText = 'extension',
				required = true,
				limit = 64,
			},
			[2] = UI.TextEntry {
				width = 20,
				formLabel = 'Program', formKey = 'value',
				shadowText = 'program',
				required = true,
				limit = 128,
			},
			add = UI.Button {
				x = -11, y = 1,
				text = 'Add', event = 'add_association',
			},
		},
		statusBar = UI.StatusBar {
			backgroundColor = colors.cyan,
		},
	},
	accelerators = {
		[ 'control-q' ] = 'quit',
		c               = 'cedit',
		e               = 'edit',
		s               = 'shell',
		p               = 'pastebin',
		r               = 'refresh',
		[ ' ' ]         = 'mark',
		m               = 'mark',
		backspace       = 'updir',
		u               = 'unmark',
		d               = 'delete',
		delete          = 'delete',
		[ 'control-h' ] = 'toggle_hidden',
		[ 'control-s' ] = 'toggle_dirSize',
		[ 'control-x' ] = 'cut',
		[ 'control-c' ] = 'copy',
		paste           = 'paste',
	},
}

function Browser:enable()
	UI.Page.enable(self)
	self:setFocus(self.grid)
end

function Browser.menuBar:getActive(menuItem)
	local file = Browser.grid:getSelected()
	if menuItem.flags == FILE then
		return file and not file.isDir
	end
	return true
end

function Browser.grid:sortCompare(a, b)
	if self.sortColumn == 'fsize' then
		return a.size < b.size
	elseif self.sortColumn == 'flags' then
		return a.flags < b.flags
	end
	if a.isDir == b.isDir then
		return a.name:lower() < b.name:lower()
	end
	return a.isDir
end

function Browser.grid:getRowTextColor(file)
	if file.marked then
		return colors.green
	end
	if file.isDir then
		return colors.cyan
	end
	if file.isReadOnly then
		return colors.pink
	end
	return colors.white
end

function Browser.grid:eventHandler(event)
	if event.type == 'copy' then -- let copy be handled by parent
		return false
	end
	return UI.ScrollingGrid.eventHandler(self, event)
end

function Browser.statusBar:draw()
	if self.parent.dir then
		local info = '#:' .. Util.size(self.parent.dir.files)
		local numMarked = Util.size(marked)
		if numMarked > 0 then
			info = info .. ' M:' .. numMarked
		end
		self:setValue('info', info)
		self:setValue('totalSize', formatSize(self.parent.dir.totalSize))
		UI.StatusBar.draw(self)
	end
end

function Browser:setStatus(status, ...)
	self.notification:info(string.format(status, ...))
end

function Browser:unmarkAll()
	for _,m in pairs(marked) do
		m.marked = false
	end
	Util.clear(marked)
end

function Browser:getDirectory(directory)
	local s, dir = pcall(function()

		local dir = directories[directory]
		if not dir then
			dir = {
				name = directory,
				size = 0,
				files = { },
				totalSize = 0,
				index = 1
			}
			directories[directory] = dir
		end

		self:updateDirectory(dir)

		return dir
	end)

	return s, dir
end

function Browser:updateDirectory(dir)

	dir.size = 0
	dir.totalSize = 0
	Util.clear(dir.files)

	local files = fs.listEx(dir.name)
	if files then
		dir.size = #files
		for _, file in pairs(files) do
			file.fullName = fs.combine(dir.name, file.name)
			file.flags = ''
			if not file.isDir then
				dir.totalSize = dir.totalSize + file.size
				file.fsize = formatSize(file.size)
			else
				if config.showDirSizes then
					file.size = fs.getSize(file.fullName, true)

					dir.totalSize = dir.totalSize + file.size
					file.fsize = formatSize(file.size)
				end
				file.flags = 'D'
			end
			if file.isReadOnly then
				file.flags = file.flags .. 'R'
			end
			if config.showHidden or file.name:sub(1, 1) ~= '.' then
				dir.files[file.fullName] = file
			end
		end
	end
--  self.grid:update()
--  self.grid:setIndex(dir.index)
	self.grid:setValues(dir.files)
end

function Browser:setDir(dirName, noStatus)
	self:unmarkAll()

	if self.dir then
		self.dir.index = self.grid:getIndex()
	end
	local DIR = fs.combine('', dirName)
	shell.setDir(DIR)
	local s, dir = self:getDirectory(DIR)
	if s then
		self.dir = dir
	elseif noStatus then
		error(dir)
	else
		self:setStatus(dir)
		self:setDir('', true)
		return
	end

	if not noStatus then
		self.statusBar:setValue('status', '/' .. self.dir.name)
		self.statusBar:draw()
	end
	self.grid:setIndex(self.dir.index)
end

function Browser:run(...)
	if multishell then
		local tabId = shell.openTab(...)
		multishell.setFocus(tabId)
	else
		shell.run(...)
		Event.terminate = false
		self:draw()
	end
end

function Browser:hasMarked()
	if Util.size(marked) == 0 then
		local file = self.grid:getSelected()
		if file then
			file.marked = true
			marked[file.fullName] = file
			self.grid:draw()
		end
	end
	return Util.size(marked) > 0
end

function Browser:eventHandler(event)
	local file = self.grid:getSelected()

	if event.type == 'quit' then
		Event.exitPullEvents()

	elseif event.type == 'edit' and file then
		self:run('edit', file.name)

	elseif event.type == 'cedit' and file then
		self:run('cedit', file.name)
		self:setStatus('Started cloud edit')

	elseif event.type == 'shell' then
		self:run('sys/apps/shell.lua')

	elseif event.type == 'refresh' then
		self:updateDirectory(self.dir)
		self.grid:draw()
		self:setStatus('Refreshed')

	elseif event.type == 'associate' then
		self.associations:show()

	elseif event.type == 'pastebin' then
		if file and not file.isDir then
			local s, m = pastebin.put(file.fullName)
			if s then
				os.queueEvent('clipboard_copy', s)
				self.notification:success(string.format('Uploaded as %s', s), 0)
			else
				self.notification:error(m)
			end
		end

	elseif event.type == 'toggle_hidden' then
		config.showHidden = not config.showHidden
		Config.update('Files', config)

		self:updateDirectory(self.dir)
		self.grid:draw()
		if not config.showHidden then
			self:setStatus('Hiding hidden')
		else
			self:setStatus('Displaying hidden')
		end

	elseif event.type == 'toggle_dirSize' then
		config.showDirSizes = not config.showDirSizes
		Config.update('Files', config)

		self:updateDirectory(self.dir)
		self.grid:draw()
		if config.showDirSizes then
			self:setStatus('Displaying dir sizes')
		end

	elseif event.type == 'mark' and file then
		file.marked = not file.marked
		if file.marked then
			marked[file.fullName] = file
		else
			marked[file.fullName] = nil
		end
		self.grid:draw()
		self.statusBar:draw()

	elseif event.type == 'unmark' then
		self:unmarkAll()
		self.grid:draw()
		self:setStatus('Marked files cleared')

	elseif event.type == 'grid_select' or event.type == 'run' then
		if file then
			if file.isDir then
				self:setDir(file.fullName)
			else
				local ext = file.name:match('%.(%w+)$')
				if ext and config.associations[ext] then
					self:run(config.associations[ext], '/' .. file.fullName)
				else
					self:run(file.name)
				end
			end
		end

	elseif event.type == 'updir' then
		local dir = (self.dir.name:match("(.*/)"))
		self:setDir(dir or '/')

	elseif event.type == 'delete' then
		if self:hasMarked() then
			local width = self.statusBar:getColumnWidth('status')
			self.statusBar:setColumnWidth('status', UI.term.width)
			self.statusBar:setValue('status', 'Delete marked? (y/n)')
			self.statusBar:draw()
			self.statusBar:sync()
			local _, ch = os.pullEvent('char')
			if ch == 'y' or ch == 'Y' then
				for _,m in pairs(marked) do
					pcall(function()
						fs.delete(m.fullName)
					end)
				end
			end
			marked = { }
			self.statusBar:setColumnWidth('status', width)
			self.statusBar:setValue('status', '/' .. self.dir.name)
			self:updateDirectory(self.dir)

			self.statusBar:draw()
			self.grid:draw()
			self:setFocus(self.grid)
		end

	elseif event.type == 'copy' or event.type == 'cut' then
		if self:hasMarked() then
			cutMode = event.type == 'cut'
			Util.clear(copied)
			Util.merge(copied, marked)
			--self:unmarkAll()
			self.grid:draw()
			self:setStatus('Copied %d file(s)', Util.size(copied))
		end

	elseif event.type == 'copy_path' then
		if file then
			os.queueEvent('clipboard_copy', file.fullName)
		end

	elseif event.type == 'paste' then
		for _,m in pairs(copied) do
			local s, m = pcall(function()
				if cutMode then
					fs.move(m.fullName, fs.combine(self.dir.name, m.name))
				else
					fs.copy(m.fullName, fs.combine(self.dir.name, m.name))
				end
			end)
		end
		self:updateDirectory(self.dir)
		self.grid:draw()
		self:setStatus('Pasted ' .. Util.size(copied) .. ' file(s)')

	else
		return UI.Page.eventHandler(self, event)
	end
	self:setFocus(self.grid)
	return true
end

--[[ Associations slide out ]] --
function Browser.associations:show()
	self.grid.values = { }
	for k, v in pairs(config.associations) do
		table.insert(self.grid.values, {
			name = k,
			value = v,
		})
	end
	self.grid:update()
	UI.SlideOut.show(self)
	self:setFocus(self.form[1])
end

function Browser.associations:eventHandler(event)
	if event.type == 'remove_entry' then
		local row = self.grid:getSelected()
		if row then
			Util.removeByValue(self.grid.values, row)
			self.grid:update()
			self.grid:draw()
		end

	elseif event.type == 'add_association' then
		if self.form:save() then
			local entry = Util.find(self.grid.values, 'name', self.form[1].value) or { }
			entry.name = self.form[1].value
			entry.value = self.form[2].value
			table.insert(self.grid.values, entry)
			self.form[1]:reset()
			self.form[2]:reset()
			self.grid:update()
			self.grid:draw()
		end

	elseif event.type == 'cancel' then
		self:hide()

	elseif event.type == 'save' then
		config.associations = { }
		for _, v in pairs(self.grid.values) do
			config.associations[v.name] = v.value
		end
		Config.update('Files', config)
		self:hide()

	else
		return UI.SlideOut.eventHandler(self, event)
	end
	return true
end

--[[-- Startup logic --]]--
local args = Util.parse(...)

Browser:setDir(args[1] or shell.dir())

UI:setPage(Browser)

Event.pullEvents()
UI.term:reset()

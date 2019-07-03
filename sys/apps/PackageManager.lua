local Ansi     = require('opus.ansi')
local Packages = require('opus.packages')
local UI       = require('opus.ui')
local Util     = require('opus.util')

local colors   = _G.colors
local term     = _G.term

UI:configure('PackageManager', ...)

local page = UI.Page {
	grid = UI.ScrollingGrid {
		x = 2, ex = 14, y = 2, ey = -5,
		values = { },
		columns = {
			{ heading = 'Package', key = 'name' },
		},
		sortColumn = 'name',
		autospace = true,
		help = 'Select a package',
	},
	add = UI.Button {
		x = 2, y = -3,
		text = 'Install',
		event = 'action',
		help = 'Install or update',
	},
	remove = UI.Button {
		x = 12, y = -3,
		text = 'Remove ',
		event = 'action',
		operation = 'uninstall',
		operationText = 'Remove',
		help = 'Remove',
	},
	updateall = UI.Button {
		ex = -2, y = -3, width = 12,
		text = 'Update All',
		event = 'updateall',
		help = 'Update all installed packages',
	},
	description = UI.TextArea {
		x = 16, y = 3, ey = -5,
		marginRight = 0, marginLeft = 0,
	},
	action = UI.SlideOut {
		backgroundColor = colors.cyan,
		titleBar = UI.TitleBar {
			event = 'hide-action',
		},
		button = UI.Button {
			x = -10, y = 3,
			text = ' Begin ', event = 'begin',
		},
		output = UI.Embedded {
			y = 5, ey = -2, x = 2, ex = -2,
			visible = true,
		},
	},
	statusBar = UI.StatusBar { },
}

function page:loadPackages()
	self.grid.values = { }
	self.statusBar:setStatus('Downloading...')
	self:sync()

	for k in pairs(Packages:list()) do
		local manifest = Packages:getManifest(k)
		if not manifest then
			manifest = {
				invalid = true,
				description = 'Unable to download manifest',
				title = '',
			}
		end
		table.insert(self.grid.values, {
			installed = not not Packages:isInstalled(k),
			name = k,
			manifest = manifest,
		})
	end
	self.grid:update()
	self.grid:setIndex(1)
	self.grid:emit({
		type = 'grid_focus_row',
		selected = self.grid:getSelected(),
		element = self.grid,
	})
	self.statusBar:setStatus('Updated packages')
end

function page.grid:getRowTextColor(row, selected)
	if row.installed then
		return colors.yellow
	end
	return UI.Grid.getRowTextColor(self, row, selected)
end

function page.action:show()
	self.output.win:clear()
	UI.SlideOut.show(self)
	--self.output:draw()
	--self.output.win.redraw()
end

function page:run(operation, name)
	local oterm = term.redirect(self.action.output.win)
	self.action.output:clear()
	local cmd = string.format('package %s %s', operation, name)
	term.setCursorPos(1, 1)
	term.clear()
	term.setTextColor(colors.yellow)
	print(cmd .. '\n')
	term.setTextColor(colors.white)
	local s, m = Util.run(_ENV, '/sys/apps/package.lua', operation, name)

	if not s and m then
		_G.printError(m)
	end
	term.redirect(oterm)
	self.action.output:draw()
end

function page:updateSelection(selected)
	self.add.operation = selected.installed and 'update' or 'install'
	self.add.operationText = selected.installed and 'Update' or 'Install'
	self.add.text = selected.installed and 'Update' or 'Install'
	self.remove.inactive = not selected.installed
	self.add:draw()
	self.remove:draw()
end

function page:eventHandler(event)
	if event.type == 'focus_change' then
		self.statusBar:setStatus(event.focused.help)

	elseif event.type == 'grid_focus_row' then
		local manifest = event.selected.manifest

		self.description.value = string.format('%s%s\n\n%s%s',
			Ansi.yellow, manifest.title,
			Ansi.white, manifest.description)
		self.description:draw()
		self:updateSelection(event.selected)

	elseif event.type == 'updateall' then
		self.operation = 'updateall'
		self.action.button.text = ' Begin '
		self.action.button.event = 'begin'
		self.action.titleBar.title = 'Update All'
		self.action:show()

	elseif event.type == 'action' then
		local selected = self.grid:getSelected()
		if selected then
			self.operation = event.button.operation
			self.action.button.text = event.button.operationText
			self.action.titleBar.title = selected.manifest.title
			self.action.button.text = ' Begin '
			self.action.button.event = 'begin'
			self.action:show()
		end

	elseif event.type == 'hide-action' then
		self.action:hide()

	elseif event.type == 'begin' then
		if self.operation == 'updateall' then
			self:run(self.operation, '')
		else
			local selected = self.grid:getSelected()
			self:run(self.operation, selected.name)
			selected.installed = Packages:isInstalled(selected.name)

			self:updateSelection(selected)
		end

		self.action.button.text = ' Done  '
		self.action.button.event = 'hide-action'
		self.action.button:draw()

	elseif event.type == 'quit' then
		UI:exitPullEvents()
	end
	UI.Page.eventHandler(self, event)
end

UI:setPage(page)
page.statusBar:setStatus('Downloading...')
page:sync()
Packages:downloadList()
page:loadPackages()
page:sync()

UI:pullEvents()

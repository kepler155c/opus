local colors  = _G.colors
local fs      = _G.fs
local http    = _G.http
local install = _ENV.install
local os      = _G.os

local injector
if not install.testing then
	_G.OPUS_BRANCH = 'develop-1.8'
	local url ='https://raw.githubusercontent.com/kepler155c/opus/develop-1.8/sys/apis/injector.lua'
	injector = load(http.get(url).readAll(), 'injector.lua', nil, _ENV)()
else
	injector = _G.requireInjector
end

injector(_ENV)

if not install.testing then
	if package then
		for _ = 1, 4 do
			table.remove(package.loaders, 1)
		end
	end
end

local Git  = require('git')
local UI   = require('ui')
local Util = require('util')

local currentFile = ''
local currentProgress = 0
local cancelEvent

local args = { ... }
local steps = install.steps[args[1] or 'install']

if not steps then
	error('Invalid install type')
end

local mode = steps[#steps]

if UI.term.width < 32 then
	cancelEvent = 'quit'
end

local page = UI.Page {
	backgroundColor = colors.cyan,
	titleBar = UI.TitleBar {
		event = cancelEvent,
	},
	wizard = UI.Wizard {
		y = 2, ey = -2,
	},
	notification = UI.Notification(),
	accelerators = {
		q = 'quit',
	},
}

local pages = {
	splash  = UI.Viewport { },
	review  = UI.Viewport { },
	license = UI.Viewport {
		backgroundColor = colors.black,
	},
	branch  = UI.Window {
		grid = UI.ScrollingGrid {
			ey = -3,
			columns = {
				{ heading = 'Branch',      key = 'branch' },
				{ heading = 'Description', key = 'description' },
			},
			values = install.branches,
			autospace = true,
		},
	},
	files   = UI.Window {
		grid = UI.ScrollingGrid {
			ey = -3,
			columns = {
				{ heading = 'Files', key = 'file' },
			},
			sortColumn = 'file',
		},
	},
	install = UI.Window {
		progressBar = UI.ProgressBar {
			y = -1,
		},
	},
	uninstall = UI.Window {
		progressBar = UI.ProgressBar {
			y = -1,
		},
	},
}

local function getFileList()
	if install.gitRepo then
		local gitFiles = Git.list(string.format('%s/%s', install.gitRepo, install.gitBranch or 'master'))
		install.files = { }
		install.diskspace = 0
		for path, entry in pairs(gitFiles) do
			install.files[path] = entry.url
			install.diskspace = install.diskspace + entry.size
		end
	end

	if not install.files or Util.empty(install.files) then
		error('File list is missing or empty')
	end
end

--[[ Splash ]]--
function pages.splash:enable()
	page.titleBar.title = 'Installer v1.0'
	UI.Viewport.enable(self)
end

function pages.splash:draw()
	self:clear()
	self:setCursorPos(1, 1)
	self:print(
		string.format('%s v%s\n', install.title, install.version), nil, colors.yellow)
	self:print(
		string.format('By: %s\n\n%s\n', install.author, install.description))

	self.ymax = self.cursorY
end

--[[ License ]]--
function pages.license:enable()
	page.titleBar.title = 'License Review'
	page.wizard.nextButton.text = 'Accept'
	UI.Viewport.enable(self)
end

function pages.license:draw()
	self:clear()
	self:setCursorPos(1, 1)
	self:print(
		string.format('Copyright (c) %s %s\n\n', install.copyrightYear,
																						 install.copyrightHolders),
			nil, colors.yellow)
	self:print(install.license)

	self.ymax = self.cursorY + 1
end

--[[ Review ]]--
function pages.review:enable()
	if mode == 'uninstall' then
		page.nextButton.text = 'Remove'
		page.titleBar.title = 'Remove Installed Files'
	else
		page.wizard.nextButton.text = 'Begin'
		page.titleBar.title = 'Download and Install'
	end
	UI.Viewport.enable(self)
end

function pages.review:draw()
	self:clear()
	self:setCursorPos(1, 1)

	local text = 'Ready to begin installation.\n\nProceeding will download and install the files to the hard drive.'
	if mode == 'uninstall' then
		text = 'Ready to begin.\n\nProceeding will remove the files previously installed.'
	end
	self:print(text)

	self.ymax = self.cursorY + 1
end

--[[ Files ]]--
function pages.files:enable()
	page.titleBar.title = 'Review Files'
	self.grid.values = { }
	for k,v in pairs(install.files) do
		table.insert(self.grid.values, { file = k, code = v })
	end
	self.grid:update()
	UI.Window.enable(self)
end

function pages.files:draw()
	self:clear()

	local function formatSize(size)
		if size >= 1000000 then
			return string.format('%dM', math.floor(size/1000000, 2))
		elseif size >= 1000 then
			return string.format('%dK', math.floor(size/1000, 2))
		end
		return size
	end

	if install.diskspace then

		local bg = self.backgroundColor

		local diskFree = fs.getFreeSpace('/')
		if install.diskspace > diskFree then
			bg = colors.red
		end

		local text = string.format('Space Required: %s, Free: %s',
				formatSize(install.diskspace), formatSize(diskFree))

		if #text > self.width then
			text = string.format('Space: %s Free: %s',
				formatSize(install.diskspace), formatSize(diskFree))
		end

		self:write(1, self.height, Util.widthify(text, self.width), bg)
	end
	self.grid:draw()
end

--[[
function pages.files:view(url)
	local s, m = pcall(function()
		page.notification:info('Downloading')
		page:sync()
		Util.download(url, '/.source')
	end)
	page.notification:disable()
	if s then
		shell.run('edit /.source')
		fs.delete('/.source')
		page:draw()
		page.notification:cancel()
	else
		page.notification:error(m:gsub('.*: (.*)', '%1'))
	end
end

function pages.files:eventHandler(event)
	if event.type == 'grid_select' then
		self:view(event.selected.code)
		return true
	end
end
--]]

local function drawCommon(self)
	if currentFile then
		self:write(1, 3, 'File:')
		self:write(1, 4, Util.widthify(currentFile, self.width))
	else
		self:write(1, 3, 'Finished')
	end
	if self.failed then
		self:write(1, 5, Util.widthify(self.failed, self.width), colors.red)
	end
	self:write(1, self.height - 1, 'Progress')

	self.progressBar.value = currentProgress
	self.progressBar:draw()
	self:sync()
end

--[[ Branch ]]--
function pages.branch:enable()
	page.titleBar.title = 'Select Branch'
	UI.Window.enable(self)
end

function pages.branch:eventHandler(event)
	-- user is navigating to next view (not previous)
	if event.type == 'enable_view' and event.next then
		install.gitBranch = self.grid:getSelected().branch
		getFileList()
	end
end

--[[ Install ]]--
function pages.install:enable()
	page.wizard.cancelButton:disable()
	page.wizard.previousButton:disable()
	page.wizard.nextButton:disable()

	page.titleBar.title = 'Installing...'
	page.titleBar.event = nil

	UI.Window.enable(self)

	page:draw()
	page:sync()

	local i = 0
	local numFiles = Util.size(install.files)
	for filename,url in pairs(install.files) do
		currentFile = filename
		currentProgress = i / numFiles * 100
		self:draw(self)
		self:sync()
		local s, m = pcall(function()
			Util.download(url, fs.combine(install.directory or '', filename))
		end)
		if not s then
			self.failed = m:gsub('.*: (.*)', '%1')
			break
		end
		i = i + 1
	end

	if not self.failed then
		currentProgress = 100
		currentFile = nil

		if install.postInstall then
			local s, m = pcall(function() install.postInstall(page, UI) end)
			if not s then
				self.failed = m:gsub('.*: (.*)', '%1')
			end
		end
	end

	page.wizard.nextButton.text = 'Exit'
	page.wizard.nextButton.event = 'quit'
	if not self.failed and install.rebootAfter then
		page.wizard.nextButton.text = 'Reboot'
		page.wizard.nextButton.event = 'reboot'
	end

	page.wizard.nextButton:enable()
	page:draw()
	page:sync()

	if not self.failed and Util.key(args, 'automatic') then
		if install.rebootAfter then
			os.reboot()
		else
			UI:exitPullEvents()
		end
	end
end

function pages.install:draw()
	self:clear()
	local text = 'The files are being installed'
	if #text > self.width then
		text = 'Installing files'
	end
	self:write(1, 1, text, nil, colors.yellow)

	drawCommon(self)
end

--[[ Uninstall ]]--
function pages.uninstall:enable()
	page.wizard.cancelButton:disable()
	page.wizard.previousButton:disable()
	page.wizard.nextButton:disable()

	page.titleBar.title = 'Uninstalling...'
	page.titleBar.event = nil

	page:draw()
	page:sync()

	UI.Window.enable(self)

	local function pruneDir(dir)
		if #dir > 0 then
			if fs.exists(dir) then
				local files = fs.list(dir)
				if #files == 0 then
					fs.delete(dir)
					pruneDir(fs.getDir(dir))
				end
			end
		end
	end

	local i = 0
	local numFiles = Util.size(install.files)
	for k in pairs(install.files) do
		currentFile = k
		currentProgress = i / numFiles * 100
		self:draw()
		self:sync()
		fs.delete(k)
		pruneDir(fs.getDir(k))
		i = i + 1
	end

	currentProgress = 100
	currentFile = nil

	page.wizard.nextButton.text = 'Exit'
	page.wizard.nextButton.event = 'quit'
	page.wizard.nextButton:enable()

	page:draw()
	page:sync()
end

function pages.uninstall:draw()
	self:clear()
	self:write(1, 1, 'Uninstalling files', nil, colors.yellow)
	drawCommon(self)
end

function page:eventHandler(event)
	if event.type == 'cancel' then
		UI:exitPullEvents()

	elseif event.type == 'reboot' then
		os.reboot()

	elseif event.type == 'quit' then
		UI:exitPullEvents()

	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

function page:enable()
	UI.Page.enable(self)
	self:setFocus(page.wizard.nextButton)
	if UI.term.width < 32 then
		page.wizard.cancelButton:disable()
		page.wizard.previousButton.x = 2
	end
end

getFileList()

local wizardPages = { }
for k,v in ipairs(steps) do
	if not pages[v] then
		error('Invalid step: ' .. v)
	end
	wizardPages[k] = pages[v]
	wizardPages[k].index = k
	wizardPages[k].x = 2
	wizardPages[k].y = 2
	wizardPages[k].ey = -3
	wizardPages[k].ex = -2
end
page.wizard:add(wizardPages)

if Util.key(steps, 'install') and install.preInstall then
	install.preInstall(page, UI)
end

UI:setPage(page)
local s, m = pcall(function() UI:pullEvents() end)
if not s then
	UI.term:reset()
	_G.printError(m)
end

local Ansi   = require('opus.ansi')
local Event  = require('opus.event')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local fs         = _G.fs
local peripheral = _G.peripheral

local source, target

local function getDriveInfo(tgt)
	local total = 0
	local throttle = Util.throttle()

	tgt = fs.combine(tgt, '')
	local src = fs.getNode(tgt).source or tgt

	local function recurse(path)
		throttle()
		if fs.isDir(path) then
			if path ~= src then
				total = total + 500
			end
			for _, v in pairs(fs.native.list(path)) do
				recurse(fs.combine(path, v))
			end
		else
			local sz = fs.getSize(path)
			total = total + math.max(500, sz)
		end
	end

	recurse(src)

	local drive = fs.getDrive(src)
	return {
		path  = tgt,
		drive  = drive,
		type  = peripheral.getType(drive) or drive,
		used  = total,
		free  = fs.getFreeSpace(src),
		mountPoint = src,
	}
end

local function getDrives(exclude)
	local drives = { }

	for _, path in pairs(fs.native.list('/')) do
		local side = fs.getDrive(path)
		if side and not drives[side] and not fs.isReadOnly(path) and side ~= exclude then
			if side == 'hdd' then
				path = ''
			end
			drives[side] = getDriveInfo(path)
		end
	end
	return drives
end

local page = UI.Page {
	wizard = UI.Wizard {
		ey = -2,
		partitions = UI.WizardPage {
			index = 1,
			info = UI.TextArea {
				x = 3, y = 2, ex = -3, ey = 5,
				value = [[Move the contents of a directory to another disk. A link will be created to point to that location.]]
			},
			grid = UI.Grid {
				x = 2, y = 7, ex = -2, ey = -2,
				columns = {
					{ heading = 'Path', key = 'path', textColor = 'yellow', width = 10 },
					{ heading = 'Mount Point',  key = 'mountPoint' },
					{ heading = 'Used',  key = 'used', width = 6 },
				},
				sortColumn = 'path',
				getDisplayValues = function (_, row)
					row = Util.shallowCopy(row)
					row.used = Util.toBytes(row.used)
					return row
				end,
				enable = function(self)
					Event.onTimeout(0, function()
						local mounts = {
							usr = getDriveInfo('usr/config'),
							packages = getDriveInfo('packages'),
						}
						self:setValues(mounts)
						self:draw()
						self:sync()
					end)
					self:setValues({ })
					UI.Grid.enable(self)
				end,
			},
			validate = function(self)
				target = self.grid:getSelected()
				return not not target
			end,
		},
		mounts = UI.WizardPage {
			index = 2,
			info = UI.TextArea {
				x = 3, y = 2, ex = -3, ey = 5,
				value = [[Select the target disk. Labeled computers can be inserted into disk drives for larger volumes.]]
			},
			grid = UI.Grid {
				x = 2, y = 7, ex = -2, ey = -2,
				columns = {
					{ heading = 'Path', key = 'path', textColor = 'yellow', width = 10 },
					{ heading = 'Type', key = 'type' },
					{ heading = 'Side',  key = 'drive' },
					{ heading = 'Free',  key = 'free', width = 6 },
				},
				sortColumn = 'path',
				getDisplayValues = function (_, row)
					row = Util.shallowCopy(row)
					row.free = Util.toBytes(row.free)
					return row
				end,
				getRowTextColor = function(self, row)
					if row.free < target.used then
						return 'lightGray'
					end
					return UI.Grid.getRowTextColor(self, row)
				end,
				enable = function(self)
					Event.on({ 'disk', 'disk_eject', 'partition_update' }, function()
						self:setValues(getDrives(target.drive))
						self:draw()
						self:sync()
					end)
					os.queueEvent('partition_update')
					self:setValues({ })
					UI.Grid.enable(self)
				end,
			},
			validate = function(self)
				source = self.grid:getSelected()
				if not source then
					self:emit({ type = 'notify', message = 'No drive selected' })
				elseif source.free < target.used then
					self:emit({ type = 'notify', message = 'Insufficient disk space' })
				else
					return true
				end
			end,
		},
		confirm = UI.WizardPage {
			index = 3,
			info = UI.TextArea {
				x = 2, y = 2, ex = -2, ey = -2,
				marginTop = 1, marginLeft = 1,
				backgroundColor = 'black',
			},
			enable = function(self)
				local fstab = Util.readFile('usr/etc/fstab')
				local lines = { }
				table.insert(lines, string.format('%sReview changes%s\n', Ansi.yellow, Ansi.reset))
				if fstab then
					for _,l in ipairs(Util.split(fstab)) do
						l = Util.trim(l)
						if #l > 0 and l:sub(1, 1) ~= '#' then
							local m = Util.matches(l)
							if m and m[1] and m[1] == target.path then
								table.insert(lines, string.format('Removed from usr/etc/fstab:\n%s%s%s\n', Ansi.red, l, Ansi.reset))
							end
						end
					end
				end
				local t = target.path
				local s = fs.combine(source.path .. '/' .. target.path, '')
				if t ~= s then
					table.insert(lines, string.format('Added to usr/etc/fstab:\n%s%s linkfs %s%s\n', Ansi.green, t, s, Ansi.reset))
				end

				table.insert(lines, string.format('Move directory:\n%s/%s -> /%s', Ansi.green, target.mountPoint, s))

				self.info:setText(table.concat(lines, '\n'))
				UI.WizardPage.enable(self)
			end,
			validate = function(self)
				if self.changesApplied then
					return true
				end
				local fstab = Util.readFile('usr/etc/fstab')
				local lines = { }
				if fstab then
					for _,l in ipairs(Util.split(fstab)) do
						table.insert(lines, l)
						l = Util.trim(l)
						if #l > 0 and l:sub(1, 1) ~= '#' then
							local m = Util.matches(l)
							if m and m[1] and m[1] == target.path then
								fs.unmount(m[1])
								table.remove(lines)
							end
						end
					end
				end

				local t = target.path
				local s = fs.combine(source.path .. '/' .. target.path, '')

				fs.move('/' .. target.mountPoint, '/' .. s)

				if t ~= s then
					table.insert(lines, string.format('%s linkfs %s', t, s))
					fs.mount(t, 'linkfs', s)
				end

				Util.writeFile('usr/etc/fstab', table.concat(lines, '\n'))

				self.parent.nextButton.text = 'Exit'
				self.parent.cancelButton:disable()
				self.parent.previousButton:disable()

				self.changesApplied = true
				self.info:setValue('Changes have been applied')
				self.parent:draw()
			end,
		},
	},
	notification = UI.Notification { },
	eventHandler = function(self, event)
		if event.type == 'notify' then
			self.notification:error(event.message)
		elseif event.type == 'accept' or event.type == 'cancel' then
			UI:quit()
		end
		return UI.Page.eventHandler(self, event)
	end,
}

UI:disableEffects()
UI:setPage(page)
UI:start()

local UI     = require('opus.ui')
local Event  = require('opus.event')
local NFT    = require('opus.nft')

local colors     = _G.colors
local fs         = _G.fs
local os         = _G.os
local peripheral = _G.peripheral

local NftImages = {
	blank = '\30\56\31\55\153\153\153\153\153\153\153\153\10\30\55\31\56\153\153\153\153\153\153\153\153\10\30\56\31\55\153\153\153\153\153\153\153\153\10\30\55\31\56\153\153\153\153\153\153\153\153\10\30\56\31\55\153\153\153\153\153\153\153\153',
	drive = '\30\32\31\32\32\30\98\31\98\128\30\56\31\56\128\128\30\102\149\30\98\149\31\57\139\10\30\32\31\32\32\30\98\31\98\128\128\128\128\128\128\10\30\32\31\32\32\30\98\31\98\128\30\48\31\55\95\95\95\95\30\98\31\98\128\10\30\32\31\32\32\30\98\31\98\128\30\48\31\55\95\95\95\95\30\98\31\98\128',
	rom   = '\30\57\31\57\128\31\56\144\144\144\144\144\31\57\128\10\30\56\31\57\157\30\55\31\55\128\128\128\128\128\30\57\31\56\145\10\30\57\31\56\136\30\55\31\55\128\30\55\31\48\82\79\77\30\55\128\30\57\31\56\132\10\30\56\31\57\157\30\55\31\55\128\128\128\128\128\30\57\31\56\145\10\30\57\31\57\128\31\56\129\129\129\129\129\31\57\128',
	hdd   = '\30\32\31\32\32\30\55\31\55\128\30\48\135\131\139\30\55\128\10\30\32\31\32\32\30\48\31\55\149\31\48\128\30\55\131\30\48\128\30\55\149\10\30\32\31\32\32\30\55\31\48\130\30\48\31\55\144\30\56\31\48\133\30\55\159\129\10\30\32\31\32\32\30\56\31\55\149\129\142\159\30\55\128\10\30\32\31\32\32\30\57\31\55\143\143\143\143\143',
}

local tab = UI.Tab {
	tabTitle = 'Disks Usage',
	description = 'Visualise HDD and disks usage',

	drives = UI.ScrollingGrid {
		x = 2, y = 1,
		ex = '47%', ey = -7,
		columns = {
			{ heading = 'Drive', key = 'name' },
			{ heading = 'Side' ,key = 'side', textColor = colors.yellow }
		},
		sortColumn = 'name',
	},
	infos = UI.Grid {
		x = '52%', y = 2,
		ex = -2, ey = -4,
		disableHeader = true,
		unfocusedBackgroundSelectedColor = colors.black,
		inactive = true,
		backgroundSelectedColor = colors.black,
		columns = {
			{ key = 'name' },
			{ key = 'value', align = 'right', textColor = colors.yellow },
		}
	},

	progress = UI.ProgressBar {
		x = 11, y = -2,
		ex = -2,
	},
	percentage = UI.Text {
		x = 11, y = -3,
		ex = '47%',
		align = 'center',
	},
	icon = UI.NftImage {
		x = 2, y = -5,
		image = NFT.parse(NftImages.blank)
	},
}

local function getDrives()
	local unique = { ['hdd'] = true, ['virt'] = true }
	local drives = { { name = 'hdd', side = '' } }

	for _, drive in pairs(fs.list('/')) do
		local side = fs.getDrive(drive)
		if side and not unique[side] then
			unique[side] = true
			table.insert(drives, { name = drive, side = side })
		end
	end
	return drives
end

local function getDriveInfo(p)
	local files, dirs, total = 0, 0, 0

	if p == "hdd" then p = "/" end
	p = fs.combine(p, '')
	local drive = fs.getDrive(p)

	local function recurse(path)
		if fs.getDrive(path) == drive then
			if fs.isDir(path) then
				if path ~= p then
					total = total + 500
					dirs = dirs + 1
				end
				for _, v in pairs(fs.list(path)) do
					recurse(fs.combine(path, v))
				end
			else
				local sz = fs.getSize(path)
				files = files + 1
				if drive == 'rom' then
					total = total + sz
				else
					total = total + math.max(500, sz)
				end
			end
		end
	end

	recurse(p)

	local info = {}
	table.insert(info, { name = 'Type', value = peripheral.getType(drive) or drive })
	table.insert(info, { name = 'Used', value = total })
	table.insert(info, { name = 'Total', value = total + fs.getFreeSpace(p) })
	table.insert(info, { name = 'Free', value = fs.getFreeSpace(p) })
	table.insert(info, { })
	table.insert(info, { name = 'Files', value = files })
	table.insert(info, { name = 'Dirs', value = dirs })
	return info, math.floor((total / (total + fs.getFreeSpace(p))) * 100)
end

function tab:updateInfo()
	local selected = self.drives:getSelected()
	local info, percent = getDriveInfo(selected and selected.name or self.drives.values[1].name)
	self.infos:setValues(info)
	self.progress.value = percent
	self.percentage.value = ('%#3d%%'):format(percent)
	self.icon.image = NFT.parse(NftImages[info[1].value] or NftImages.blank)
	self:draw()
end

function tab:updateDrives()
	local drives = getDrives()
	self.drives:setValues(drives)
end

function tab:enable()
	self:updateDrives()
	self:updateInfo()
	UI.Tab.enable(self)
end

function tab:eventHandler(event)
	if event.type == 'grid_focus_row' then
		self:updateInfo()
	else
		return UI.Tab.eventHandler(self, event)
	end
	return true
end

Event.on({ 'disk', 'disk_eject' }, function()
	os.sleep(1)
	tab:updateDrives()
	tab:updateInfo()
	tab:sync()
end)

return tab

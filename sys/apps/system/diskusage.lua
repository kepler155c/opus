local UI     = require('opus.ui')
local Event  = require('opus.event')
local NFT    = require('opus.nft')

local colors     = _G.colors
local fs         = _G.fs
local os         = _G.os
local peripheral = _G.peripheral

local NftImages = {
	blank = '\0308\0317\153\153\153\153\153\153\153\153\010\0307\0318\153\153\153\153\153\153\153\153\010\0308\0317\153\153\153\153\153\153\153\153\010\0307\0318\153\153\153\153\153\153\153\153\010\0308\0317\153\153\153\153\153\153\153\153',
	drive = '\030 \031  \030b\031b\128\0308\0318\128\128\030f\149\030b\149\031 \139\010\030 \031  \030b\031b\128\128\128\128\128\128\010\030 \031  \030b\031b\128\0300\0317____\030b\031b\128\010\030 \031  \030b\031b\128\0300\0317____\030b\031b\128',
	ram   = '\030 \031 \128\0318\144\144\144\144\144\031 \128\010\0308\031 \157\0307\0317\128\128\128\128\128\030 \0318\145\010\030 \0318\136\0307\0317\128\0307\0310RAM\0307\128\030 \0318\132\010\0308\031 \157\0307\0317\128\128\128\128\128\030 \0318\145\010\030 \031 \128\0318\129\129\129\129\129\031 \128',
	rom   = '\030 \031 \128\0318\144\144\144\144\144\031 \128\010\0308\031 \157\0307\0317\128\128\128\128\128\030 \0318\145\010\030 \0318\136\0307\0317\128\0307\0310ROM\0307\128\030 \0318\132\010\0308\031 \157\0307\0317\128\128\128\128\128\030 \0318\145\010\030 \031 \128\0318\129\129\129\129\129\031 \128',
	hdd   = '\030 \031  \0307\0317\128\0300\135\131\139\0307\128\010\030 \031  \0300\0317\149\0310\128\0307\131\0300\128\0307\149\010\030 \031  \0307\0310\130\0300\0317\144\0308\0310\133\0307\159\129\010\030 \031  \0308\0317\149\129\142\159\0307\128\010\030 \031  \030 \0317\143\143\143\143\143',
}

local tab = UI.Tab {
	title = 'Disks Usage',
	description = 'Visualise HDD and disks usage',

	drives = UI.ScrollingGrid {
		x = 2, y = 2,
		ex = '47%', ey = -8,
		columns = {
			{ heading = 'Drive', key = 'name' },
			{ heading = 'Side' ,key = 'side', textColor = colors.yellow }
		},
		sortColumn = 'name',
	},
	infos = UI.Grid {
		x = '52%', y = 2,
		ex = -2, ey = -8,
		disableHeader = true,
		unfocusedBackgroundSelectedColor = colors.black,
		inactive = true,
		backgroundSelectedColor = colors.black,
		columns = {
			{ key = 'name' },
			{ key = 'value', align = 'right', textColor = colors.yellow },
		}
	},
	[1] = UI.Window {
		x = 2, y = -6, ex = -2, ey = -2,
		backgroundColor = colors.black,
	},
	progress = UI.ProgressBar {
		x = 11, y = -3,
		ex = -3,
	},
	percentage = UI.Text {
		y = -4, width = 5,
		x = 12,
		--align = 'center',
		backgroundColor = colors.black,
	},
	icon = UI.NftImage {
		x = 2, y = -6, ey = -2,
		backgroundColor = colors.black,
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
	self.handler = Event.on({ 'disk', 'disk_eject' }, function()
		os.sleep(1)
		tab:updateDrives()
		tab:updateInfo()
		tab:sync()
	end)
end

function tab:disable()
	Event.off(self.handler)
	UI.Tab.disable(self)
end

function tab:eventHandler(event)
	if event.type == 'grid_focus_row' then
		self:updateInfo()
	else
		return UI.Tab.eventHandler(self, event)
	end
	return true
end

return tab

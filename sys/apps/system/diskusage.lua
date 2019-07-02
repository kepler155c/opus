local UI     = require('opus.ui')
local Event  = require('opus.event')
local Util   = require('opus.util')
local NFT    = require('opus.nft')

local NftImages = {
  blank = '\30\56\31\55\153\153\153\153\153\153\153\153\10\30\55\31\56\153\153\153\153\153\153\153\153\10\30\56\31\55\153\153\153\153\153\153\153\153\10\30\55\31\56\153\153\153\153\153\153\153\153\10\30\56\31\55\153\153\153\153\153\153\153\153',
  drive = '',
  rom   = '',
  hdd   = '',
}

local tab = UI.Tab {
  tabTitle = '1.Disks Usage',
  description = 'Visualise HDD and disks usage',
  drives = UI.ScrollingGrid {
    y = 2, ey = 9, x = 2, ex = '47%',
    columns = {
      { heading = 'Drive', key = 'name' },
      { heading = 'Side' ,key = 'side' }
    },
    sortColumn = 'name',
  },
  infos = UI.Grid {
    x = '52%', y = 3, ex = -2, ey = 9,
    disableHeader = true,
    unfocusedBackgroundSelectedColor = colors.black,
    inactive = true,
    backgroundSelectedColor = colors.black, --??
    columns = {
      {key = 'name' },
      {key = 'value', align = 'right' },
    }
  },

  progress = UI.ProgressBar {
    x = 11, y = 11, ex = -2,
    barChar = '\127',
    textColor = colors.blue,
    backgroundColor = colors.black,
  },
  percentage = UI.Text {
    x = 11, y = 12, ex = -2,
    align = 'center',
  },
  icon = UI.NftImage {
    x = 2, y = 11,
    image = NFT.parse(NftImages.blank)
  },
}

local function getDrives()
  local unique = { ['hdd'] = true, ['virt'] = true }
  local exclude = {}
  local drives = {
    {name = 'hdd', side = ''},
  }
  for _, drive in pairs(fs.list('/')) do
   local side = fs.getDrive(drive)
    if side and not unique[side] then
      unique[side] = true
      exclude[drive] = true
      table.insert(drives, {name=drive, side=side})
    end
  end
  return drives, exclude
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
  self:draw()
end

function tab:updateDrives()
  local drives, exclude = getDrives()
  self.exclude = exclude
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
  end
  return UI.Tab.eventHandler(self, event)
end

Event.on({ 'disk', 'disk_eject' }, function()
  sleep(1)
  tab:updateDrives()
  tab:updateInfo()
  tab:sync()
end)

return tab

local UI   = require('opus.ui')
local Util = require('opus.util')

local fs   = _G.fs
local os   = _G.os

local labelTab = UI.Tab {
	tabTitle = 'Label',
	description = 'Set the computer label',
	labelText = UI.Text {
		x = 3, y = 2,
		value = 'Label'
	},
	label = UI.TextEntry {
		x = 9, y = 2, ex = -4,
		limit = 32,
		value = os.getComputerLabel(),
		accelerators = {
			enter = 'update_label',
		},
	},
	grid = UI.ScrollingGrid {
		y = 3,
		values = {
			{ name = '',  value = ''                  },
			{ name = 'CC version',  value = Util.getVersion()                  },
			{ name = 'Lua version', value = _VERSION                           },
			{ name = 'MC version',  value = Util.getMinecraftVersion()         },
			{ name = 'Disk free',   value = Util.toBytes(fs.getFreeSpace('/')) },
			{ name = 'Computer ID', value = tostring(os.getComputerID())       },
			{ name = 'Day',         value = tostring(os.day())                 },
		},
		inactive = true,
		columns = {
			{ key = 'name',  width = 12 },
			{ key = 'value' },
		},
	},
}

function labelTab:eventHandler(event)
	if event.type == 'update_label' then
		os.setComputerLabel(self.label.value)
		self:emit({ type = 'success_message', message = 'Label updated' })
		return true
	end
end

return labelTab

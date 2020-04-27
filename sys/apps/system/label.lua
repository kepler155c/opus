local UI   = require('opus.ui')
local Util = require('opus.util')

local fs   = _G.fs
local os   = _G.os

return UI.Tab {
	title = 'Label',
	description = 'Set the computer label',
	labelText = UI.Text {
		x = 3, y = 3,
		value = 'Label'
	},
	label = UI.TextEntry {
		x = 9, y = 3, ex = -4,
		limit = 32,
		value = os.getComputerLabel(),
		accelerators = {
			enter = 'update_label',
		},
	},
	[1] = UI.Window {
		x = 2, y = 2, ex = -2, ey = 4,
	},
	grid = UI.ScrollingGrid {
		x = 2, y = 5, ex = -2, ey = -2,
		values = {
			{ name = '',  value = ''                  },
			{ name = 'CC version',  value = Util.getVersion()                  },
			{ name = 'Lua version', value = _VERSION                           },
			{ name = 'MC version',  value = Util.getMinecraftVersion()         },
			{ name = 'Disk free',   value = Util.toBytes(fs.getFreeSpace('/')) },
			{ name = 'Computer ID', value = tostring(os.getComputerID())       },
			{ name = 'Day',         value = tostring(os.day())                 },
		},
		disableHeader = true,
		inactive = true,
		columns = {
			{ key = 'name',  width = 12 },
			{ key = 'value', textColor = colors.yellow },
		},
	},
	eventHandler = function(self, event)
		if event.type == 'update_label' and self.label.value then
			os.setComputerLabel(self.label.value)
			self:emit({ type = 'success_message', message = 'Label updated' })
			return true
		end
	end,
}

local Ansi   = require('opus.ansi')
local Config = require('opus.config')
local UI     = require('opus.ui')

local colors = _G.colors
local device = _G.device

return UI.Tab {
	title = 'Network',
	description = 'Networking options',
	info = UI.TextArea {
		x = 2, y = 5, ex = -2, ey = -2,
		backgroundColor = colors.black,
		marginLeft = 1, marginRight = 1, marginTop = 1,
		value = string.format(
[[%sSet the primary modem used for wireless communications.%s

Reboot to take effect.]], Ansi.yellow, Ansi.reset)
	},
	[1] = UI.Window {
		x = 2, y = 2, ex = -2, ey = 4,
	},
	label = UI.Text {
		x = 3, y = 3,
		value = 'Modem',
	},
	modem = UI.Chooser {
		x = 10, ex = -3, y = 3,
		nochoice = 'auto',
	},
	enable = function(self)
		local width = 7
		local choices = {
			{ name = 'auto',    value = 'auto' },
			{ name = 'disable', value = 'none' },
		}

		for k,v in pairs(device) do
			if v.isWireless and v.isWireless() and k ~= 'wireless_modem' then
				table.insert(choices, { name = k, value = v.name })
				width = math.max(width, #k)
			end
		end

		self.modem.choices = choices
		--self.modem.width = width + 4

		local config = Config.load('os')
		self.modem.value = config.wirelessModem or 'auto'

		UI.Tab.enable(self)
	end,
	eventHandler = function(self, event)
		if event.type == 'choice_change' then
			local config = Config.load('os')
			config.wirelessModem = self.modem.value
			Config.update('os', config)
			self:emit({ type = 'success_message', message = 'reboot to take effect' })
			return true
		end
	end
}

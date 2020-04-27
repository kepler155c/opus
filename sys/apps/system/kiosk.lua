local UI = require('opus.ui')

local colors     = _G.colors
local peripheral = _G.peripheral
local settings   = _G.settings

return peripheral.find('monitor') and UI.Tab {
	title = 'Kiosk',
	description = 'Kiosk options',
	form = UI.Form {
		x = 2, y = 2, ex = -2, ey = 5,
		manualControls = true,
		monitor = UI.Chooser {
			formLabel = 'Monitor', formKey = 'monitor',
		},
		textScale = UI.Chooser {
			formLabel = 'Font Size', formKey = 'textScale',
			nochoice = 'Small',
			choices = {
				{ name = 'Small', value = '.5' },
				{ name = 'Large', value = '1'  },
			},
			help = 'Adjust text scaling',
		},
	},
	labelText = UI.TextArea {
		x = 2, ex = -2, y = 7, ey = -2,
		textColor = colors.yellow,
		backgroundColor = colors.black,
		value = 'Settings apply to kiosk mode selected during startup'
	},
	enable = function(self)
		local choices = { }

		peripheral.find('monitor', function(side)
			table.insert(choices, { name = side, value = side })
		end)

		self.form.monitor.choices = choices
		self.form.monitor.value = settings.get('kiosk.monitor')

		self.form.textScale.value = settings.get('kiosk.textscale')

		UI.Tab.enable(self)
	end,
	eventHandler = function(self, event)
		if event.type == 'choice_change' then
			if self.form.monitor.value then
				settings.set('kiosk.monitor', self.form.monitor.value)
			end
			if self.form.textScale.value then
				settings.set('kiosk.textscale', self.form.textScale.value)
			end
			settings.save('.settings')
		end
	end
}

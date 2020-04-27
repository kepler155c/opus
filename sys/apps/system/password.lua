local Security = require('opus.security')
local SHA      = require('opus.crypto.sha2')
local UI       = require('opus.ui')

return UI.Tab {
	title = 'Password',
	description = 'Wireless network password',
	[1] = UI.Window {
		x = 2, y = 2, ex = -2, ey = 4,
	},
	newPass = UI.TextEntry {
		x = 3, ex = -3, y = 3,
		limit = 32,
		mask = true,
		shadowText = 'new password',
		accelerators = {
			enter = 'new_password',
		},
	},
	button = UI.Button {
		x = -8, ex = -2, y = -2,
		text = 'Apply',
		event = 'update_password',
	},
	info = UI.TextArea {
		x = 2, ex = -2, y = 5, ey = -4,
		backgroundColor = 'black',
		textColor = 'yellow',
		inactive = true,
		marginLeft = 1, marginRight = 1, marginTop = 1,
		value = 'Add a password to enable other computers to connect to this one.',
	},
	eventHandler = function(self, event)
		if event.type == 'update_password' then
			if not self.newPass.value or #self.newPass.value == 0 then
				self:emit({ type = 'error_message', message = 'Invalid password' })

			else
				Security.updatePassword(SHA.compute(self.newPass.value))
				self:emit({ type = 'success_message', message = 'Password updated' })
			end
			return true
		end
	end
}

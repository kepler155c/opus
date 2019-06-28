local Security = require('opus.security')
local SHA      = require('opus.crypto.sha2')
local UI       = require('opus.ui')

local colors   = _G.colors

local passwordTab = UI.Tab {
	tabTitle = 'Password',
	description = 'Wireless network password',
	oldPass = UI.TextEntry {
		x = 3, ex = -3, y = 2,
		limit = 32,
		mask = true,
		shadowText = 'old password',
		inactive = not Security.getPassword(),
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
		x = 3, y = 5,
		text = 'Update',
		event = 'update_password',
	},
	info = UI.TextArea {
		x = 3, ex = -3, y = 7,
		textColor = colors.yellow,
		inactive = true,
		value = 'Add a password to enable other computers to connect to this one.',
	}
}
function passwordTab:eventHandler(event)
	if event.type == 'update_password' then
		if #self.newPass.value == 0 then
			self:emit({ type = 'error_message', message = 'Invalid password' })

		elseif Security.getPassword() and not Security.verifyPassword(SHA.compute(self.oldPass.value)) then
			self:emit({ type = 'error_message', message = 'Passwords do not match' })

		else
			Security.updatePassword(SHA.compute(self.newPass.value))
			self.oldPass.inactive = false
			self:emit({ type = 'success_message', message = 'Password updated' })
		end
		return true
	end
end

return passwordTab

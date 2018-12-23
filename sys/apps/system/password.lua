local Security = require('security')
local SHA1     = require('sha1')
local UI       = require('ui')

local passwordTab = UI.Window {
	tabTitle = 'Password',
	description = 'Wireless network password',
	oldPass = UI.TextEntry {
		x = 2, y = 2, ex = -2,
		limit = 32,
		mask = true,
		shadowText = 'old password',
		inactive = not Security.getPassword(),
	},
	newPass = UI.TextEntry {
		y = 3, x = 2, ex = -2,
		limit = 32,
		mask = true,
		shadowText = 'new password',
		accelerators = {
			enter = 'new_password',
		},
	},
	button = UI.Button {
		x = 2, y = 5,
		text = 'Update',
		event = 'update_password',
	},
	info = UI.TextArea {
		x = 2, ex = -2,
		y = 7,
		inactive = true,
		value = 'Add a password to enable other computers to connect to this one.',
	}
}
function passwordTab:eventHandler(event)
	if event.type == 'update_password' then
		if #self.newPass.value == 0 then
			self:emit({ type = 'error_message', message = 'Invalid password' })

		elseif Security.getPassword() and not Security.verifyPassword(SHA1.sha1(self.oldPass.value)) then
			self:emit({ type = 'error_message', message = 'Passwords do not match' })

		else
			Security.updatePassword(SHA1.sha1(self.newPass.value))
			self.oldPass.inactive = false
			self:emit({ type = 'success_message', message = 'Password updated' })
		end
		return true
	end
end

return passwordTab

local Ansi     = require('ansi')
local Security = require('security')
local SHA1     = require('sha1')
local UI       = require('ui')

local colors   = _G.colors
local os       = _G.os
local shell    = _ENV.shell

local splashIntro = [[First Time Setup

%sThanks for installing Opus OS. The next screens will prompt you for basic settings for this computer.]]
local labelIntro = [[Set a friendly name for this computer.

%sNo spaces recommended.]]
local passwordIntro = [[A password is required for wireless access.

%sLeave blank to skip.]]
local packagesIntro = [[Setup Complete

%sOpen the package manager to add software to this computer.]]

local page = UI.Page {
	wizard = UI.Wizard {
    ey = -2,
		pages = {
			splash = UI.WizardPage {
        index = 1,
        intro = UI.TextArea {
          textColor = colors.yellow,
          inactive = true,
          x = 3, ex = -3, y = 2, ey = -2,
          value = string.format(splashIntro, Ansi.white),
        },
      },
			label = UI.WizardPage {
        index = 2,
        labelText = UI.Text {
          x = 3, y = 2,
          value = 'Label'
        },
        label = UI.TextEntry {
          x = 9, y = 2, ex = -3,
          limit = 32,
          value = os.getComputerLabel(),
        },
        intro = UI.TextArea {
          textColor = colors.yellow,
          inactive = true,
          x = 3, ex = -3, y = 4, ey = -3,
          value = string.format(labelIntro, Ansi.white),
        },
      },
			password = UI.WizardPage {
				index = 3,
        labelText = UI.Text {
          x = 3, y = 2,
          value = 'Password'
        },
        newPass = UI.TextEntry {
          x = 12, ex = -3, y = 2,
          limit = 32,
          mask = true,
          shadowText = 'password',
          accelerators = {
            enter = 'new_password',
          },
        },
        intro = UI.TextArea {
          textColor = colors.yellow,
          inactive = true,
          x = 3, ex = -3, y = 4, ey = -3,
          value = string.format(passwordIntro, Ansi.white),
        },
			},
			packages = UI.WizardPage {
				index = 4,
        button = UI.Button {
          x = 3, y = -3,
          text = 'Open Package Manager',
          event = 'packages',
        },
        intro = UI.TextArea {
          textColor = colors.yellow,
          inactive = true,
          x = 3, ex = -3, y = 2, ey = -3,
          value = string.format(packagesIntro, Ansi.white),
        },
			},
		},
  },
  notification = UI.Notification { },
}

function page.wizard.pages.label:validate()
  os.setComputerLabel(self.label.value)
  return true
end

function page.wizard.pages.password:validate()
  if #self.newPass.value > 0 then
    Security.updatePassword(SHA1.sha1(self.newPass.value))
  end
  return true
end

function page:eventHandler(event)
  if event.type == 'skip' then
    self.wizard:emit({ type = 'nextView' })

  elseif event.type == 'view_enabled' then
    event.view:focusFirst()

  elseif event.type == 'packages' then
    shell.openForegroundTab('PackageManager')

  elseif event.type == 'wizard_complete' or event.type == 'cancel' then
    UI.exitPullEvents()

	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

UI:setPage(page)
UI:pullEvents()

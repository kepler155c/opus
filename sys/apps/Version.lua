local Config = require('opus.config')
local UI = require('opus.ui')

local shell = _ENV.shell

local config = Config.load('version')
if not config.current then
    return
end

UI:setPage(UI.Page {
    UI.Text {
        x = 2, y = 2, ex = -2,
        align = 'center',
        value = 'Opus has been updated.',
        textColor = 'yellow',
    },
    UI.TextArea {
        x = 2, y = 4, ey = -8,
        value = config.details,
    },
    UI.Button {
        x = 2, y = -6, width = 21,
        event = 'skip',
        text = 'Skip this version',
    },
    UI.Button {
        x = 2, y = -4, width = 21,
        event = 'remind',
        text = 'Remind me tomorrow',
    },
    UI.Button {
        x = 2, y = -2, width = 21,
        event = 'update',
        text = 'Update'
    },
    eventHandler = function(self, event)
        if event.type == 'skip' then
            config.skip = config.current
            Config.update('version', config)
            UI:quit()

        elseif event.type == 'remind' then
            UI:quit()

        elseif event.type == 'update' then
            shell.openForegroundTab('update update')
            UI:quit()
        end
        return UI.Page.eventHandler(self, event)
    end,
})

UI:start()

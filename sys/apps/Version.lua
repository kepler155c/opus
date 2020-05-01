local Config = require('opus.config')
local UI = require('opus.ui')

local shell = _ENV.shell

local config = Config.load('version')
if not config.current then
    return
end

UI:setPage(UI.Page {
    UI.TextArea {
        x = 2, y = 2, ey = -2,
        value = 'A new version of Opus is available.'
    },
    UI.Button {
        x = 2, y = 5, width = 21,
        event = 'skip',
        text = 'Skip this version',
    },
    UI.Button {
        x = 2, y = 7, width = 21,
        event = 'remind',
        text = 'Remind me tomorrow',
    },
    UI.Button {
        x = 2, y = 9, width = 21,
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

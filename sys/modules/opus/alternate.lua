local Array  = require('opus.array')
local Config = require('opus.config')
local Util   = require('opus.util')

local function getConfig()
    return Config.load('alternate', {
        default = {
            shell = 'sys/apps/shell.lua',
            lua = 'sys/apps/Lua.lua',
            files = 'sys/apps/Files.lua',
        },
        choices = {
            shell = {
                'sys/apps/shell.lua',
                'rom/programs/shell',
            },
            lua = {
                'sys/apps/Lua.lua',
                'rom/programs/lua.lua',
            },
            files = {
                'sys/apps/Files.lua',
            }
        }
    })
end

local Alt = { }

function Alt.get(key)
    return getConfig().default[key]
end

function Alt.set(key, value)
    local config = getConfig()

    Alt.addChoice(key, value)

    config.default[key] = value
    Config.update('alternate', config)
end

function Alt.remove(key, value)
    local config = getConfig()

    Array.removeByValue(config.choices[key], value)
    if config.default[key] == value then
        config.default[key] = config.choices[key][1]
    end
    Config.update('alternate', config)
end

function Alt.addChoice(key, value)
    local config = getConfig()

    if not config.choices[key] then
        config.choices[key] = { }
    end
    if not Util.contains(config.choices[key], value) then
        table.insert(config.choices[key], value)
        Config.update('alternate', config)
    end
end

return Alt

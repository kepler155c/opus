local fs = _G.fs

-- cleanup outdated files
fs.delete('sys/apps/shell')
fs.delete('sys/etc/app.db')
fs.delete('sys/extensions')
fs.delete('sys/network')
fs.delete('startup')
fs.delete('sys/apps/system/turtle.lua')
fs.delete('sys/autorun/gps.lua')
fs.delete('sys/autorun/gpshost.lua')
fs.delete('sys/apps/network/redserver.lua')
if fs.exists('sys/apis') then fs.delete('sys/apis') end
fs.delete('sys/autorun/apps.lua')

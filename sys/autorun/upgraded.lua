if fs.exists('sys/apps/shell') and fs.exists('sys/apps/shell.lua') then
  fs.delete('sys/apps/shell')
end
if fs.exists('sys/etc/app.db') then fs.delete('sys/etc/app.db') end
if fs.exists('sys/extensions') then fs.delete('sys/extensions') end
if fs.exists('sys/network') then fs.delete('sys/network') end
if fs.exists('startup') then fs.delete('startup') end

if fs.exists('sys/autorun/gps.lua') then fs.delete('sys/autorun/gps.lua') end
if fs.exists('sys/apps/network/redserver.lua') then fs.delete('sys/apps/network/redserver.lua') end
if fs.exists('sys/apis') then fs.delete('sys/apis') end

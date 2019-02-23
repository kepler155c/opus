if fs.exists('sys/apps/shell') and fs.exists('sys/apps/shell.lua') then
  fs.delete('sys/apps/shell')
end
if fs.exists('sys/autorun/gps.lua') then fs.delete('sys/autorun/gps.lua') end
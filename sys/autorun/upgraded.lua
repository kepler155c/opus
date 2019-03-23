if fs.exists('sys/apps/shell') and fs.exists('sys/apps/shell.lua') then
  fs.delete('sys/apps/shell')
end
if fs.exists('sys/etc/app.db') then fs.delete('sys/etc/app.db') end
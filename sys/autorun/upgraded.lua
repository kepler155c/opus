local fs = _G.fs

local function deleteIfExists(path)
  if fs.exists(path) then
    fs.delete(path)
    print("Deleted outdated file at: "..path)
  end
end
-- cleanup outdated files
deleteIfExists('sys/apps/shell')
deleteIfExists('sys/etc/app.db')
deleteIfExists('sys/extensions')
deleteIfExists('sys/network')
deleteIfExists('startup')
deleteIfExists('sys/apps/system/turtle.lua')
deleteIfExists('sys/autorun/gps.lua')
deleteIfExists('sys/autorun/gpshost.lua')
deleteIfExists('sys/apps/network/redserver.lua')
deleteIfExists('sys/apis')
deleteIfExists('sys/autorun/apps.lua')

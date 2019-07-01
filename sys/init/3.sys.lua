local fs = _G.fs

fs.mount('rom/modules/main/opus', 'linkfs', 'sys/modules/opus')
fs.loadTab('sys/etc/fstab')

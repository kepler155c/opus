fs.mount('sys/apps/pain.lua', 'urlfs', 'http://pastebin.com/raw/wJQ7jav0')
fs.mount('sys/apps/update.lua', 'urlfs', 'http://pastebin.com/raw/UzGHLbNC')
fs.mount('sys/apps/Enchat.lua', 'urlfs', 'https://raw.githubusercontent.com/LDDestroier/enchat/master/enchat3.lua')
fs.mount('sys/apps/cloud.lua', 'urlfs', 'https://cloud-catcher.squiddev.cc/cloud.lua')

-- baking this in before a PR to cc:tweaked
os.loadAPI('sys/apis/pastebin.lua')
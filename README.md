
# Opus OS for computercraft

<img src="https://github.com/kepler155c/opus-wiki/blob/master/assets/images/opus.gif?raw=true" width="540" height="360">

## Features
* Multitasking OS - run programs in separate tabs
* Telnet (wireless remote shell)
* VNC (wireless screen sharing)
* UI API
* Turtle API (includes true pathfinding based on the ASTAR algorithm)
* Remote file system access (you can access the file system of any computer in wireless range)
* File manager
* Lua REPL with GUI
* Run scripts on single or groups of computers (GUI)
* Turtle follow (with GPS) and turtle come to you (without GPS)

## Install
First run this:
```
lua
```
Then insert this:
```lua
local r = http.get("https://pastebin.com/raw/jCfCfBPn​"); local f = fs.open( shell.resolve( "pastebin" ), "w" ); f.write( r.readAll() ); f.close(); r.close()
```
This crates a new copy of pastebin program, with fixed HTTPS.  
Press enter, then insert this and press enter:
```lua
exit()
```
This exits the lua bash.
Then run this:
```
pastebin run UzGHLbNC
```
This downloads and immedeately runs the installer.

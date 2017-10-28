# rbx-sync

## Description

A utility to listen for remote requests to read/write to files.
Obviously this is a bit of a security hazard, so don't do any port forwarding (this script uses port 605) to do it remotely.
This script ties in nicely with this plugin: https://www.roblox.com/library/1137204740/File-Push-Pull

## To Setup:

This tool requires that Lua 5.1 is installed on your PC & it has access to the following libraries:
* lfs (LuaFileSystem)
* socket (LuaSocket)

These are included when you install [LuaForWindows](https://github.com/rjpcomputing/luaforwindows), so do that.

After that, you may want a nice shortcut to boot up the server. I would advise creating a shortcut to invoke launch.bat & place this in Startup.
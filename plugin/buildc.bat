@echo off

set file="plugin.min.lua"

timeout 1

:CheckFile
if exist %file% goto CopyFile
timeout 1
goto CheckFile

:CopyFile
mkdir %localappdata%\Roblox\Plugins\RSync
copy %file% ..\src\plugin.min.lua
exit
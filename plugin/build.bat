setlocal
cd /d %~dp0

start buildc.bat
moonc plugin.moon
luamin -f plugin.lua > plugin.min.lua
exit
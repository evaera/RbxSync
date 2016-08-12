setlocal
cd /d %~dp0

start cake config
start buildc.bat
moonc plugin.moon
luamin -f plugin.lua > plugin.min.lua
exit
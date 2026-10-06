@echo off
echo explorer.exe已关闭！
taskkill /im explorer.exe /f
echo 正在开启explorer.exe
start "" "C:\WINDOWS\explorer.exe"
echo explorer.exe已开启！
ping -n 4 127.1>nul
exit
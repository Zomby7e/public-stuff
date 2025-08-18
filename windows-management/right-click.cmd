@echo off
echo Enter 1 to set classic right-click menu
echo Enter 2 to set new right-click menu (Windows 11)
echo Enter something else to exit
set menutype=0
set /p menutype=
if not "%menutype%"=="1" if not "%menutype%"=="2" goto end
if "%menutype%"=="1" (
	reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve && taskkill /f /im explorer.exe && start explorer.exe
)

if "%menutype%"=="2" (
	reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f && taskkill /f /im explorer.exe && start explorer.exe
) 
:end
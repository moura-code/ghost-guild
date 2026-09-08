@echo off
setlocal
if "%GODOT_BIN%"=="" set GODOT_BIN=godot
for %%I in ("%~dp0..") do set ROOT=%%~fI
set "APPDATA=%TEMP%\ghost-guild-tests-%RANDOM%-%RANDOM%"
mkdir "%APPDATA%"
set ARGS=
:loop
if "%~1"=="" goto run
set ARGS=%ARGS% -a %~1
shift
goto loop
:run
"%GODOT_BIN%" --headless --path "%ROOT%" --import >nul 2>&1
"%GODOT_BIN%" --headless --path "%ROOT%" -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c %ARGS%
set TEST_RESULT=%ERRORLEVEL%
rmdir /s /q "%APPDATA%"
exit /b %TEST_RESULT%

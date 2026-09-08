@echo off
rem Launches the game. Double-click it, or run `tools\play.cmd` from anywhere.
rem
rem Uses the windowed Godot binary rather than GODOT_BIN, which points at the
rem _console build: that one works but opens a black console window beside the
rem game, which is right for the test runner and wrong for playing.
rem
rem   tools\play.cmd          play
rem   tools\play.cmd fresh    start a new campaign (the old save is kept, renamed)
setlocal
for %%I in ("%~dp0..") do set ROOT=%%~fI

set GAME_BIN=%GODOT_BIN%
if "%GAME_BIN%"=="" set GAME_BIN=godot
set GAME_BIN=%GAME_BIN:_console.exe=.exe%

set SAVE=%APPDATA%\Godot\app_userdata\Ghost Guild\saves\slot1.json
if /I "%~1"=="fresh" (
  if exist "%SAVE%" (
    for /f "tokens=1-4 delims=/ " %%a in ("%DATE%") do set STAMP=%%d%%b%%c
    move "%SAVE%" "%SAVE%.old" >nul 2>&1
    echo Old save moved to slot1.json.old -- starting in the guild.
  )
)

echo Ghost Guild -- WASD move, mouse look, Shift run, E use, click to play a card, Esc frees the cursor.
"%GAME_BIN%" --path "%ROOT%"

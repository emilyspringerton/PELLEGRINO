@echo off
rem PELLEGRINO launcher. The exe is a windowed (no-console) build and writes real log files next to
rem itself: pellegrino.log (engine), pellegrino.out.log, pellegrino.err.log (runtime/SDL errors).
cd /d "%~dp0"
echo PELLEGRINO starting. Logs: pellegrino.log  pellegrino.err.log
start "" /wait pellegrino.exe %*
set RC=%ERRORLEVEL%
echo PELLEGRINO exited with code %RC%
if not "%RC%"=="0" (
  echo ---- pellegrino.log ----
  if exist pellegrino.log type pellegrino.log
  echo ---- pellegrino.err.log ----
  if exist pellegrino.err.log type pellegrino.err.log
  pause
)

@echo off
rem Run the autofish Python script and keep the window open on error
cd /d "%~dp0"

rem Prefer the Windows launcher if available, otherwise fallback to python
where py >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  set "PYCMD=py -3"
) else (
  where python >nul 2>&1
  if %ERRORLEVEL% EQU 0 (
    set "PYCMD=python"
  ) else (
    echo Python not found in PATH. Install Python and try again.
    pause
    exit /b 1
  )
)

echo Running autofish with %PYCMD%...
%PYCMD% "%~dp0autofish.py" %* 2> "%~dp0\autofish_error.log"
set "RC=%ERRORLEVEL%"

if %RC% NEQ 0 (
  echo.
  echo Autofish exited with error code %RC%.
  echo --- Error output (from autofish_error.log) ---
  type "%~dp0\autofish_error.log"
  echo ---------------------------------------------
  echo.
  echo Press any key to exit.
  pause >nul
  exit /b %RC%
) else (
  echo Autofish completed successfully.
  echo Press any key to exit.
  pause >nul
)

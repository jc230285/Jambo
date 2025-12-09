@echo off
rem Installer batch to install Python requirements from requirements.txt
cd /d "%~dp0"

rem Find python launcher or python executable
where py >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  set "PYCMD=py -3"
) else (
  where python >nul 2>&1
  if %ERRORLEVEL% EQU 0 (
    set "PYCMD=python"
  ) else (
    echo Python not found in PATH. Please install Python first.
    pause
    exit /b 1
  )
)

echo Installing requirements using %PYCMD% -m pip...
%PYCMD% -m pip install --upgrade pip
%PYCMD% -m pip install -r "%~dp0requirements.txt"
if %ERRORLEVEL% NEQ 0 (
  echo.
  echo Failed to install some packages. You can try running the command below manually:
  echo %PYCMD% -m pip install -r "%~dp0requirements.txt"
  pause
  exit /b %ERRORLEVEL%
)

echo All requirements installed successfully.
pause >nul

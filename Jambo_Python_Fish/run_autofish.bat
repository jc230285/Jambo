@echo off
REM run_autofish.bat - Installs python dependencies (optional) and runs autofish.py
REM Usage: run_autofish.bat [path\to\python.exe]

SETLOCAL ENABLEDELAYEDEXPANSION
REM Default to system python if not provided as an argument
IF "%~1"=="" (
  SET "PYTHON=python"
) ELSE (
  SET "PYTHON=%~1"
)



























exit /B %RET%pauseecho AutoFish exited with code %RET%set RET=%ERRORLEVEL%%PYTHON% "%~dp0autofish.py"echo Starting AutoFish...)  REM Do not exit automatically; allow user to continue or fix issues.  echo You can also run: %PYTHON% -m pip install --user -r "%~dp0requirements.txt"  echo Warning: pip install returned an error. You may need to run this script as Administrator, or run the pip command separately.IF ERRORLEVEL 1 (%PYTHON% -m pip install -r "%~dp0requirements.txt" --userecho Installing dependencies from requirements.txt (this may take a few minutes)...echo Using python at: %PYTHON%)  EXIT /B 1  pause  echo run_autofish.bat "C:\\Users\\jkkec\\AppData\\Local\\Programs\\Python\\Python313\\python.exe"  echo Provide a full path to python.exe as argument, for example:  echo ERROR: Python not found on PATH and no argument was provided.IF ERRORLEVEL 1 (%PYTHON% -V >nul 2>&1nREM Verify python is callable
@echo off
setlocal enabledelayedexpansion

echo ========================================
echo AutoFish Launcher - System Check
echo ========================================
echo.

REM ============================================
REM Step 1: Detect Python Installation
REM ============================================
echo [1/5] Detecting Python installation...
set "PYTHON_EXE="
set "PYTHON_VERSION="

REM Check common Python locations
for %%p in (
    "python.exe"
    "python3.exe"
    "py.exe"
    "%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
    "C:\Python313\python.exe"
    "C:\Python312\python.exe"
    "C:\Python311\python.exe"
    "C:\Python310\python.exe"
) do (
    where %%p >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "delims=" %%i in ('where %%p 2^>nul') do (
            set "PYTHON_EXE=%%i"
            goto :found_python
        )
    )
)

:found_python
if not defined PYTHON_EXE (
    echo [ERROR] Python not found!
    echo.
    echo Please install Python 3.10 or higher from:
    echo https://www.python.org/downloads/
    echo.
    echo Make sure to check "Add Python to PATH" during installation.
    echo.
    pause
    exit /b 1
)

echo [OK] Python found at: %PYTHON_EXE%

REM Get Python version
for /f "tokens=2" %%v in ('"%PYTHON_EXE%" --version 2^>^&1') do set "PYTHON_VERSION=%%v"
echo [OK] Python version: %PYTHON_VERSION%

REM Check if version is 3.10+
for /f "tokens=1,2 delims=." %%a in ("%PYTHON_VERSION%") do (
    set MAJOR=%%a
    set MINOR=%%b
)

if %MAJOR% lss 3 (
    echo [ERROR] Python 3.10 or higher required. Found: %PYTHON_VERSION%
    pause
    exit /b 1
)

if %MAJOR% equ 3 if %MINOR% lss 10 (
    echo [ERROR] Python 3.10 or higher required. Found: %PYTHON_VERSION%
    pause
    exit /b 1
)

echo.

REM ============================================
REM Step 2: Upgrade pip
REM ============================================
echo [2/5] Upgrading pip to latest version...
"%PYTHON_EXE%" -m pip install --upgrade pip >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Could not upgrade pip (continuing anyway)
) else (
    echo [OK] pip upgraded successfully
)
echo.

REM ============================================
REM Step 3: Check requirements.txt
REM ============================================
echo [3/5] Checking requirements.txt...
if not exist "%~dp0requirements.txt" (
    echo [ERROR] requirements.txt not found!
    echo Expected location: %~dp0requirements.txt
    echo.
    pause
    exit /b 1
)
echo [OK] requirements.txt found
echo.

REM ============================================
REM Step 4: Install/Update dependencies
REM ============================================
echo [4/5] Installing/updating required packages...
echo This may take a moment...
echo.

"%PYTHON_EXE%" -m pip install --upgrade -r "%~dp0requirements.txt"
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to install required packages!
    echo.
    echo Please check:
    echo 1. Internet connection is active
    echo 2. Antivirus is not blocking pip
    echo 3. You have write permissions
    echo.
    pause
    exit /b 1
)

echo.
echo [OK] All packages installed/updated successfully
echo.

REM ============================================
REM Step 5: Verify critical modules
REM ============================================
echo [5/5] Verifying critical modules...

set "MISSING_MODULES="

for %%m in (cv2 numpy mss tkinter win32gui win32api PIL) do (
    "%PYTHON_EXE%" -c "import %%m" >nul 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Module '%%m' import failed
        set "MISSING_MODULES=!MISSING_MODULES! %%m"
    ) else (
        echo [OK] %%m
    )
)

if defined MISSING_MODULES (
    echo.
    echo [ERROR] Missing or broken modules:%MISSING_MODULES%
    echo.
    echo Try manually installing:
    echo "%PYTHON_EXE%" -m pip install opencv-python numpy mss pillow pywin32
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo All checks passed! Starting AutoFish...
echo ========================================
echo.
echo Python: %PYTHON_EXE%
echo Version: %PYTHON_VERSION%
echo Script: %~dp0autofish.py
echo.
echo Press Ctrl+C to stop the bot
echo ========================================
echo.

REM ============================================
REM Run the fishing bot
REM ============================================
"%PYTHON_EXE%" "%~dp0autofish.py"

REM Capture exit code
set EXIT_CODE=%errorlevel%

echo.
echo ========================================
if %EXIT_CODE% equ 0 (
    echo Bot exited normally
) else (
    echo Bot exited with error code: %EXIT_CODE%
    echo.
    echo Common issues:
    echo - World of Warcraft not running
    echo - Game window not found
    echo - Incorrect keybinds in config
    echo - Missing permissions
)
echo ========================================
echo.

pause
exit /b %EXIT_CODE%

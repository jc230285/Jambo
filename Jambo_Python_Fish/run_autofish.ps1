<#
run_autofish.ps1 - Elevate, install dependencies and run autofish.py
Usage:
  - Use PowerShell to run this script. You can provide an optional full path to python.exe as the first argument.
  - Example: .\run_autofish.ps1 "C:\Users\jkkec\AppData\Local\Programs\Python\Python313\python.exe"
  - If no python path is provided it will use `python` available on PATH.
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$PythonPath
)

function Is-Administrator {
    $current = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $current.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Elevate if not admin
if (-not (Is-Administrator)) {
    Write-Host "Script not running as Administrator. Trying to restart elevated..."
    $argsEscaped = $MyInvocation.MyCommand.Path
    if ($PythonPath) { $argsEscaped += " `"$PythonPath`"" }
    $psArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$argsEscaped`""
    Start-Process -FilePath "powershell.exe" -ArgumentList $psArgs -Verb RunAs -WindowStyle Normal
    exit
}

# Running as Administrator from here on
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $PythonPath) {
    # Try to find python on PATH
    try {
        $pythonCmd = Get-Command python -ErrorAction Stop
        $PythonPath = $pythonCmd.Source
    } catch {
        Write-Error "Python not found on PATH. Please provide full path to python.exe as argument."
        exit 1
    }
}

Write-Host "Using Python: $PythonPath"

# Verify python works
try {
    & "$PythonPath" -V
} catch {
    Write-Error "Failed to run $PythonPath. Check path and try again."
    exit 1
}

$reqFile = Join-Path $PSScriptRoot 'requirements.txt'
if (Test-Path $reqFile) {
    Write-Host "Upgrading pip and installing dependencies from $reqFile..."
    try {
        & "$PythonPath" -m pip install --upgrade pip
    } catch {
        Write-Warning "Failed to upgrade pip. Continuing to try install requirements."
    }

    try {
        & "$PythonPath" -m pip install -r "$reqFile"
    } catch {
        Write-Warning "pip returned an error while installing dependencies. You may want to inspect the message above and re-run the command as Admin or with --user flag."
    }
} else {
    Write-Warning "requirements.txt not found. Skipping package installation."
}

# Do a simple import test for the main modules used in the script
$importsTest = "import mss, cv2, numpy, PIL, win32api; print('IMPORTS OK')"

try {
    & "$PythonPath" -c $importsTest
} catch {
    Write-Warning "Import test failed. Some packages may not be installed or incompatible with this Python."
    Write-Host "You can manually re-run: $PythonPath -m pip install -r \"$reqFile\""
}

# Start the autofish script
$autoFishScript = Join-Path $PSScriptRoot 'autofish.py'
if (-not (Test-Path $autoFishScript)) {
    Write-Error "autofish.py not found in $PSScriptRoot."
    exit 1
}

Write-Host "Starting autofish.py..."
& "$PythonPath" "$autoFishScript"

$exitCode = $LASTEXITCODE
Write-Host "autofish.py exited with code: $exitCode"

Read-Host -Prompt "Press Enter to finish"
exit $exitCode

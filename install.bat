@echo off
REM ghpkg installer for Windows

SETLOCAL

REM Paths
SET "GH_PKG_DIR=%LOCALAPPDATA%\ghpkg"
SET "DB_PATH=%GH_PKG_DIR%\db.json"
SET "BIN_DIR=%GH_PKG_DIR%\bin"

REM Create directories
echo Creating directories...
IF NOT EXIST "%GH_PKG_DIR%" mkdir "%GH_PKG_DIR%"
IF NOT EXIST "%BIN_DIR%" mkdir "%BIN_DIR%"

REM Create db.json with empty JSON array if it doesn't exist
IF NOT EXIST "%DB_PATH%" (
    echo [] > "%DB_PATH%"
)

echo ghpkg installed!
echo DB path: %DB_PATH%
echo Bin folder: %BIN_DIR%
echo.
echo Add %BIN_DIR% to your PATH environment variable to use ghpkg binaries globally.
echo For example:
echo    setx PATH "%%PATH%%;%BIN_DIR%"

ENDLOCAL

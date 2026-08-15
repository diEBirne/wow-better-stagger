@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\deploy-ellesmere.ps1" %*
set EXITCODE=%ERRORLEVEL%

if %EXITCODE% NEQ 0 (
    echo.
    echo Ellesmere deploy failed with exit code %EXITCODE%.
    exit /b %EXITCODE%
)

exit /b 0

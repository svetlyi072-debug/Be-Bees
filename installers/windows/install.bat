@echo off
setlocal
title Be_Bees Setup

set "APP_NAME=Be_Bees"
set "INSTALL_DIR=%LOCALAPPDATA%\Programs\Be_Bees"
set "SRC_DIR=%~dp0"

echo ============================================
echo   Be_Bees Setup
echo ============================================
echo.
echo Installing to: %INSTALL_DIR%
echo.

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

copy /Y "%SRC_DIR%Be_Bees.exe" "%INSTALL_DIR%\Be_Bees.exe" >nul
if errorlevel 1 (
    echo ERROR: Could not copy the game files. Is the game currently running?
    pause
    exit /b 1
)
copy /Y "%SRC_DIR%icon.ico" "%INSTALL_DIR%\icon.ico" >nul

echo Creating shortcuts...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$s = (New-Object -ComObject WScript.Shell).CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Be_Bees.lnk');" ^
    "$s.TargetPath = '%INSTALL_DIR%\Be_Bees.exe';" ^
    "$s.WorkingDirectory = '%INSTALL_DIR%';" ^
    "$s.IconLocation = '%INSTALL_DIR%\icon.ico';" ^
    "$s.Save()"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$s = (New-Object -ComObject WScript.Shell).CreateShortcut('%USERPROFILE%\Desktop\Be_Bees.lnk');" ^
    "$s.TargetPath = '%INSTALL_DIR%\Be_Bees.exe';" ^
    "$s.WorkingDirectory = '%INSTALL_DIR%';" ^
    "$s.IconLocation = '%INSTALL_DIR%\icon.ico';" ^
    "$s.Save()"

echo Writing uninstaller...

rem Deletes everything except itself: a running batch file can't reliably
rem delete the folder it's executing from (several fragile tricks exist for
rem that; none of them are worth the risk here). The one leftover file is a
rem few KB - noted in its own final message so it's not a silent surprise.
(
    echo @echo off
    echo echo Removing Be_Bees...
    echo del /Q "%%APPDATA%%\Microsoft\Windows\Start Menu\Programs\Be_Bees.lnk" 2^>nul
    echo del /Q "%%USERPROFILE%%\Desktop\Be_Bees.lnk" 2^>nul
    echo reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Be_Bees" /f ^>nul 2^>nul
    echo del /Q "%INSTALL_DIR%\Be_Bees.exe" 2^>nul
    echo del /Q "%INSTALL_DIR%\icon.ico" 2^>nul
    echo echo Be_Bees has been removed. The empty folder and this script
    echo echo ^(a few KB^) are the only things left behind - delete
    echo echo "%INSTALL_DIR%" yourself if you want it gone too.
    echo pause
) > "%INSTALL_DIR%\uninstall.bat"

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Be_Bees" /f ^
    /v "DisplayName" /t REG_SZ /d "Be_Bees" >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Be_Bees" /f ^
    /v "DisplayIcon" /t REG_SZ /d "%INSTALL_DIR%\icon.ico" >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Be_Bees" /f ^
    /v "UninstallString" /t REG_SZ /d "\"%INSTALL_DIR%\uninstall.bat\"" >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Be_Bees" /f ^
    /v "Publisher" /t REG_SZ /d "Be_Bees" >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Be_Bees" /f ^
    /v "NoModify" /t REG_DWORD /d 1 >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Be_Bees" /f ^
    /v "NoRepair" /t REG_DWORD /d 1 >nul

echo.
echo ============================================
echo   Done! Be_Bees was installed.
echo   Shortcuts were added to the Desktop and
echo   Start Menu. You can remove the game later
echo   from "Add or remove programs".
echo ============================================
echo.

choice /C YN /M "Launch Be_Bees now"
if errorlevel 2 goto :end
start "" "%INSTALL_DIR%\Be_Bees.exe"

:end
endlocal

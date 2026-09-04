@echo off
setlocal enabledelayedexpansion
title JA_Symlink - Build Release Packager

set WORKSPACE_DIR=%~dp0
cd /d "%WORKSPACE_DIR%"

set APP_NAME=JA_Symlink
set EXE_NAME=ja_symlink.exe

:: Read version from pubspec.yaml (e.g. "version: 1.0.1+2" -> "1.0.1")
for /f "tokens=2 delims=: " %%v in ('findstr /b "version:" pubspec.yaml') do set PUBVER=%%v
for /f "tokens=1 delims=+" %%v in ("%PUBVER%") do set APP_VERSION=%%v

:: Keep a recoverable snapshot of the complete previous portable dist.
for /f %%t in ('powershell -NoProfile -Command "(Get-Date).ToString('yyyyMMdd_HHmmss')"') do set BACKUP_DIR=backup\dist_%%t

echo [0/8] Terminating any running %EXE_NAME% instance...
taskkill /IM %EXE_NAME% /F 2>nul
timeout /t 1 /nobreak >nul

:: The portable app stores its live history/config inside dist\. Snapshot
:: the entire directory before the clean package directory is recreated.
if exist "dist" (
    mkdir "%BACKUP_DIR%" >nul 2>&1
    xcopy /e /i /y /q "dist\*.*" "%BACKUP_DIR%\" >nul
    echo   -> Snapshotted previous dist to %BACKUP_DIR%
)

echo [1/8] Compiling Windows application (Release mode)...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed. Existing dist snapshot is preserved.
    pause
    exit /b %ERRORLEVEL%
)

set REL=build\windows\x64\runner\Release

echo [2/8] Creating .Release.lnk shortcut to the Release folder...
powershell -NoProfile -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%WORKSPACE_DIR%.Release.lnk'); $Shortcut.TargetPath = '%WORKSPACE_DIR%%REL%'; $Shortcut.Save()"

:: Remove runtime data left behind by the last .exe run from Release itself.
:: These files can contain user paths/settings and must not ship in the ZIP.
if exist "%REL%\config.ini" del /f /q "%REL%\config.ini"
if exist "%REL%\config.json" del /f /q "%REL%\config.json"
if exist "%REL%\pending_operation.json" del /f /q "%REL%\pending_operation.json"
if exist "%REL%\logs" rmdir /s /q "%REL%\logs"
if exist "%REL%\assets\data" rmdir /s /q "%REL%\assets\data"

echo [3/8] Bundling public assets, i18n, and docs...
if exist assets xcopy /e /i /y /q assets "%REL%\assets\"
:: assets\data is the local portable database, not a public release asset.
if exist "%REL%\assets\data" rmdir /s /q "%REL%\assets\data"
if exist i18n xcopy /e /i /y /q i18n "%REL%\i18n\"
if exist debug.bat copy /y debug.bat "%REL%\" >nul
if exist ABOUT.txt copy /y ABOUT.txt "%REL%\" >nul
if exist README.md copy /y README.md "%REL%\" >nul
if exist CHANGELOG.md copy /y CHANGELOG.md "%REL%\" >nul
if exist LICENSE copy /y LICENSE "%REL%\" >nul
if exist RELEASE_NOTES.md copy /y RELEASE_NOTES.md "%REL%\" >nul

echo [4/8] Copying complete clean release to dist\...
if exist dist rmdir /s /q dist
mkdir dist
xcopy /e /i /y /q "%REL%\*.*" "dist\"
if exist "dist\config.ini" del /f /q "dist\config.ini"
if exist "dist\config.json" del /f /q "dist\config.json"
if exist "dist\pending_operation.json" del /f /q "dist\pending_operation.json"
if exist "dist\logs" rmdir /s /q "dist\logs"
if exist "dist\assets\data" rmdir /s /q "dist\assets\data"

echo [5/8] Wrapping release in parent folder %APP_NAME%_v%APP_VERSION%_Windows_x64...
if exist dist_pack rmdir /s /q dist_pack
mkdir "dist_pack\%APP_NAME%_v%APP_VERSION%_Windows_x64"
xcopy /e /i /y /q "dist\*.*" "dist_pack\%APP_NAME%_v%APP_VERSION%_Windows_x64\"

echo [6/8] Compressing standalone Windows x64 ZIP release...
if exist "dist\%APP_NAME%_v%APP_VERSION%_Windows_x64.zip" del /f /q "dist\%APP_NAME%_v%APP_VERSION%_Windows_x64.zip"
powershell -NoProfile -Command "Compress-Archive -Path 'dist_pack\*' -DestinationPath 'dist\%APP_NAME%_v%APP_VERSION%_Windows_x64.zip' -Force"
if exist dist_pack rmdir /s /q dist_pack

echo [7/8] Verifying package does not contain runtime state...
powershell -NoProfile -Command "$zip = 'dist\%APP_NAME%_v%APP_VERSION%_Windows_x64.zip'; $bad = tar -tf $zip | Select-String -Pattern '(^|/)(config\.(ini|json)|logs/|assets/data/|pending_operation\.json)'; if ($bad) { Write-Error 'Runtime state found in release ZIP'; exit 1 }"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Release ZIP contains local runtime data. Aborting.
    pause
    exit /b 1
)

echo [8/8] Done.
echo [SUCCESS] Clean release package: dist\%APP_NAME%_v%APP_VERSION%_Windows_x64.zip
echo [INFO] Previous portable data remains recoverable in %BACKUP_DIR%.
pause

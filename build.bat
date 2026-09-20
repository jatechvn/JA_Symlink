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
taskkill /IM %EXE_NAME% /F >nul 2>&1
powershell -NoProfile -Command "Get-Process -Name 'ja_symlink' -ErrorAction SilentlyContinue | ForEach-Object { try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch { Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -NonInteractive -Command Stop-Process -Name ja_symlink -Force' -Wait } }"
ping 127.0.0.1 -n 2 >nul

:: The portable app stores its live history/config inside dist\. Snapshot
:: the entire directory before the clean package directory is recreated.
if exist "dist" (
    mkdir "%BACKUP_DIR%" >nul 2>&1
    xcopy /e /i /y /q "dist\*.*" "%BACKUP_DIR%\" >nul 2>&1
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

:: Remove runtime data left behind by any previous .exe run from Release itself.
attrib -r -s -h "%REL%\config.ini" >nul 2>&1
if exist "%REL%\config.ini" del /f /q "%REL%\config.ini"
attrib -r -s -h "%REL%\config.json" >nul 2>&1
if exist "%REL%\config.json" del /f /q "%REL%\config.json"
attrib -r -s -h "%REL%\pending_operation.json" >nul 2>&1
if exist "%REL%\pending_operation.json" del /f /q "%REL%\pending_operation.json"
attrib -r -s -h "%REL%\logs\*" /s /d >nul 2>&1
if exist "%REL%\logs" rmdir /s /q "%REL%\logs" 2>nul
if exist "%REL%\logs" powershell -NoProfile -Command "Remove-Item -LiteralPath '%WORKSPACE_DIR%%REL%\logs' -Recurse -Force -ErrorAction SilentlyContinue"
attrib -r -s -h "%REL%\assets\data\*" /s /d >nul 2>&1
if exist "%REL%\assets\data" rmdir /s /q "%REL%\assets\data" 2>nul
if exist "%REL%\assets\data" powershell -NoProfile -Command "Remove-Item -LiteralPath '%WORKSPACE_DIR%%REL%\assets\data' -Recurse -Force -ErrorAction SilentlyContinue"

echo [3/8] Bundling public assets, native DLLs, i18n, and docs...
:: Ensure native fast scanner DLL is compiled and bundled
if not exist ja_fast_scan.dll (
    if exist rust_core (
        echo   -> Compiling native Rust scanner core...
        pushd rust_core
        call cargo build --release
        popd
        copy /y rust_core\target\release\ja_fast_scan.dll . >nul 2>&1
    )
)
if exist ja_fast_scan.dll copy /y ja_fast_scan.dll "%REL%\" >nul

if exist assets xcopy /e /i /y /q assets "%REL%\assets\" >nul 2>&1
:: assets\data is the local portable database, not a public release asset.
attrib -r -s -h "%REL%\assets\data\*" /s /d >nul 2>&1
if exist "%REL%\assets\data" rmdir /s /q "%REL%\assets\data" 2>nul
if exist "%REL%\assets\data" powershell -NoProfile -Command "Remove-Item -LiteralPath '%WORKSPACE_DIR%%REL%\assets\data' -Recurse -Force -ErrorAction SilentlyContinue"
if exist i18n xcopy /e /i /y /q i18n "%REL%\i18n\" >nul 2>&1
if exist debug.bat copy /y debug.bat "%REL%\" >nul
if exist ABOUT.txt copy /y ABOUT.txt "%REL%\" >nul
if exist README.md copy /y README.md "%REL%\" >nul
if exist CHANGELOG.md copy /y CHANGELOG.md "%REL%\" >nul
if exist LICENSE copy /y LICENSE "%REL%\" >nul
if exist RELEASE_NOTES.md copy /y RELEASE_NOTES.md "%REL%\" >nul
if exist USERGUIDE.md copy /y USERGUIDE.md "%REL%\" >nul

echo [4/8] Copying complete clean release to dist\...
attrib -r -s -h dist\* /s /d >nul 2>&1
if exist dist rmdir /s /q dist 2>nul
if exist dist powershell -NoProfile -Command "Remove-Item -LiteralPath '%WORKSPACE_DIR%dist' -Recurse -Force -ErrorAction SilentlyContinue"
mkdir dist
xcopy /e /i /y /q "%REL%\*.*" "dist\" >nul 2>&1

attrib -r -s -h "dist\config.ini" >nul 2>&1
if exist "dist\config.ini" del /f /q "dist\config.ini"
attrib -r -s -h "dist\config.json" >nul 2>&1
if exist "dist\config.json" del /f /q "dist\config.json"
attrib -r -s -h "dist\pending_operation.json" >nul 2>&1
if exist "dist\pending_operation.json" del /f /q "dist\pending_operation.json"
attrib -r -s -h "dist\logs\*" /s /d >nul 2>&1
if exist "dist\logs" rmdir /s /q "dist\logs" 2>nul
if exist "dist\logs" powershell -NoProfile -Command "Remove-Item -LiteralPath '%WORKSPACE_DIR%dist\logs' -Recurse -Force -ErrorAction SilentlyContinue"
attrib -r -s -h "dist\assets\data\*" /s /d >nul 2>&1
if exist "dist\assets\data" rmdir /s /q "dist\assets\data" 2>nul
if exist "dist\assets\data" powershell -NoProfile -Command "Remove-Item -LiteralPath '%WORKSPACE_DIR%dist\assets\data' -Recurse -Force -ErrorAction SilentlyContinue"

echo [5/8] Wrapping release in parent folder %APP_NAME%_v%APP_VERSION%_Windows_x64...
attrib -r -s -h dist_pack\* /s /d >nul 2>&1
if exist dist_pack rmdir /s /q dist_pack 2>nul
if exist dist_pack powershell -NoProfile -Command "Remove-Item -LiteralPath '%WORKSPACE_DIR%dist_pack' -Recurse -Force -ErrorAction SilentlyContinue"
mkdir "dist_pack\%APP_NAME%_v%APP_VERSION%_Windows_x64"
xcopy /e /i /y /q "dist\*.*" "dist_pack\%APP_NAME%_v%APP_VERSION%_Windows_x64\" >nul 2>&1

:: Safety sanitization on dist_pack prior to zipping
if exist "dist_pack\%APP_NAME%_v%APP_VERSION%_Windows_x64\config.ini" del /f /q "dist_pack\%APP_NAME%_v%APP_VERSION%_Windows_x64\config.ini"
if exist "dist_pack\%APP_NAME%_v%APP_VERSION%_Windows_x64\config.json" del /f /q "dist_pack\%APP_NAME%_v%APP_VERSION%_Windows_x64\config.json"
if exist "dist_pack\%APP_NAME%_v%APP_VERSION%_Windows_x64\pending_operation.json" del /f /q "dist_pack\%APP_NAME%_v%APP_VERSION%_Windows_x64\pending_operation.json"
if exist "dist_pack\%APP_NAME%_v%APP_VERSION%_Windows_x64\logs" rmdir /s /q "dist_pack\%APP_NAME%_v%APP_VERSION%_Windows_x64\logs" 2>nul
if exist "dist_pack\%APP_NAME%_v%APP_VERSION%_Windows_x64\assets\data" rmdir /s /q "dist_pack\%APP_NAME%_v%APP_VERSION%_Windows_x64\assets\data" 2>nul

echo [6/8] Compressing standalone Windows x64 ZIP release...
if exist "dist\%APP_NAME%_v%APP_VERSION%_Windows_x64.zip" del /f /q "dist\%APP_NAME%_v%APP_VERSION%_Windows_x64.zip"
powershell -NoProfile -Command "Compress-Archive -Path 'dist_pack\*' -DestinationPath 'dist\%APP_NAME%_v%APP_VERSION%_Windows_x64.zip' -Force"
attrib -r -s -h dist_pack\* /s /d >nul 2>&1
if exist dist_pack rmdir /s /q dist_pack 2>nul

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

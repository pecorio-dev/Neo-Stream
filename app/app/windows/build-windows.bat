@echo off
REM ============================================================
REM  Neo-Stream — Build Windows (exe + setup Inno Setup)
REM  A executer sur une machine WINDOWS (PowerShell / cmd).
REM
REM  Prerequis :
REM    - Flutter SDK (flutter sur le PATH)
REM    - Inno Setup 6.x  (https://jrsoftware.org/isdl.php)
REM      apres install, iscc.exe est typiquement dans :
REM      "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
REM
REM  Usage : depuis app/app, executer :  windows\build-windows.bat
REM  Resultat : windows\Output\Neo-Stream-Setup-<version>.exe
REM ============================================================
setlocal enabledelayedexpansion

set "APP_DIR=%~dp0.."
cd /d "%APP_DIR%"

echo.
echo [1/3] flutter pub get ...
call flutter pub get
if errorlevel 1 ( echo Echec pub get & exit /b 1 )

echo.
echo [2/3] flutter build windows --release ...
call flutter build windows --release
if errorlevel 1 ( echo Echec build windows & exit /b 1 )

REM Lecture de la version depuis pubspec.yaml
for /f "tokens=2 delims=: " %%v in ('findstr /r "^version:" pubspec.yaml') do (
  set "RAW=%%v"
)
REM Garder uniquement x.y.z (avant le +)
for /f "tokens=1 delims=+" %%a in ("!RAW!") do set "VERSION=%%a"
echo Version detectee : !VERSION!

echo.
echo [3/3] Compilation Inno Setup ...
REM Trouver ISCC.exe
set "ISCC="
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if exist "C:\Program Files\Inno Setup 6\ISCC.exe" set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"

if "!ISCC!"=="" (
  echo ERREUR : Inno Setup 6 introuvable. Installez-le depuis https://jrsoftware.org/isdl.php
  exit /b 1
)

"!ISCC!" /DAppVersion="!VERSION!" "windows\inno_setup.iss"
if errorlevel 1 ( echo Echec Inno Setup & exit /b 1 )

echo.
echo ============================================================
echo  Build Windows termine :
echo  windows\Output\Neo-Stream-Setup-!VERSION!.exe
echo ============================================================
endlocal

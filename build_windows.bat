@echo off
REM Initialize VS 2022 BuildTools environment
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64

REM Set environment variables to force Flutter to use BuildTools
set "VSINSTALLDIR=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\"
set "VCToolsInstallDir=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\"
set "WindowsSdkDir=C:\Program Files (x86)\Windows Kits\10\"

REM Build Flutter Windows app
flutter build windows --release

pause

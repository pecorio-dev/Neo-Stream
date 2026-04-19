@echo off
REM Initialize VS 2022 BuildTools environment
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64

REM Use standalone CMake
set "PATH=C:\Program Files\CMake\bin;%PATH%"

REM Override VS Community paths that vcvarsall might have set
set "VSINSTALLDIR=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\"
set "VCToolsInstallDir=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\"

REM Remove Community from PATH
set "PATH=%PATH:C:\Program Files\Microsoft Visual Studio\2022\Community=%"

REM Clean build directory
if exist "build\windows" (
    echo Cleaning build directory...
    rmdir /s /q "build\windows"
)

echo.
echo Environment:
echo VSINSTALLDIR=%VSINSTALLDIR%
echo.
echo CMake version:
cmake --version
echo.

REM Build Flutter Windows app
flutter build windows --release

pause

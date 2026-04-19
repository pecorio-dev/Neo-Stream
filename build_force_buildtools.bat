@echo off
REM Initialize VS 2022 BuildTools environment
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64

REM Force use of BuildTools CMake and modules
set "PATH=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;%PATH%"
set "CMAKE_MODULE_PATH=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\share\cmake-3.31\Modules"

REM Clean build directory
if exist "build\windows" (
    echo Cleaning build directory...
    rmdir /s /q "build\windows"
)

REM Build Flutter Windows app
flutter build windows --release

pause

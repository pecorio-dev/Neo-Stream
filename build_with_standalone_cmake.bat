@echo off
REM Initialize VS 2022 BuildTools environment for compiler
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64

REM Use standalone CMake (installed via winget) instead of VS CMake
set "PATH=C:\Program Files\CMake\bin;%PATH%"

REM Verify CMake
echo Using CMake:
cmake --version

REM Clean build directory
if exist "build\windows" (
    echo Cleaning build directory...
    rmdir /s /q "build\windows"
)

REM Build Flutter Windows app
flutter build windows --release

pause

@echo off
REM Initialize VS 2022 BuildTools environment
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64

REM Use CMake from BuildTools (version 3.31, compatible)
set "PATH=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;%PATH%"

REM Remove standalone CMake from PATH to avoid conflicts
set "PATH=%PATH:C:\Program Files\CMake\bin;=%"

REM Clean build directory
if exist "build\windows" (
    echo Cleaning build directory...
    rmdir /s /q "build\windows"
)

echo.
echo Using CMake:
cmake --version
echo.

REM Build Flutter Windows app
flutter build windows --release

pause

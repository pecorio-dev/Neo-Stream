@echo off
REM Initialize VS 2022 BuildTools environment
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64

REM Use CMake from BuildTools instead of Community
set "PATH=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;%PATH%"

REM Verify CMake
echo Using CMake from:
where cmake

REM Build Flutter Windows app
flutter build windows --release

pause

@echo off
if "%~1"=="" exit /b 2
call "%~1" >nul
if errorlevel 1 exit /b 1
cd /d "%~dp0"
if not exist build mkdir build
ml64 /nologo /c /Fobuild\dispatcher.obj dispatcher.asm
if errorlevel 1 exit /b 1
cl /nologo /std:c++17 /EHsc /W4 /DUNICODE /D_UNICODE /Fobuild\DispatcherTest.obj /Febuild\DispatcherTest.exe DispatcherTest.cpp build\dispatcher.obj /link runtimeobject.lib ole32.lib
if errorlevel 1 exit /b 1
build\DispatcherTest.exe

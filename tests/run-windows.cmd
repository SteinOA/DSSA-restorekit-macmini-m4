@echo off
setlocal
for /f "usebackq tokens=*" %%I in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%I"
if not defined VSINSTALL exit /b 2
call "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat"
if errorlevel 1 exit /b 3
cl /nologo /W4 /std:c11 /D_CRT_SECURE_NO_WARNINGS tests\restore_identity_fixtures.c /Fe:fixtures.exe
if errorlevel 1 exit /b 4
cl /nologo /W4 /std:c11 /D_CRT_SECURE_NO_WARNINGS tests\identity_fuzz.c /Fe:fuzz.exe
if errorlevel 1 exit /b 5
fixtures.exe
if errorlevel 1 exit /b 6
fuzz.exe %1
exit /b %errorlevel%

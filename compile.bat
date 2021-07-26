:: =====================================================
:: Vicious DLL Injector, ver.1.0
:: © Jan Hodermarsky (HardC0re, JohnHoder), 2015-2017
:: =====================================================

@echo off

if not exist .\res\res.rc goto over1
echo "Compiling resources ..."
rc.exe /v .\res\res.rc
cvtres.exe /machine:ix86 .\res\res.res

:over1
if exist %1.obj del injector.obj
if exist %1.exe del injector.exe
ml.exe /c /coff /Cp /I"C:\masm32\include" .\src\injector.asm
if errorlevel 1 goto errasm
if not exist .\res\res.obj goto nores

echo "Linking ..."
link.exe /SUBSYSTEM:WINDOWS .\injector.obj .\res\res.obj /LIBPATH:"C:\masm32\lib" /OUT:"injector.exe"
if errorlevel 1 goto errlink
goto TheEnd

:nores
echo "Linking without resources ..."
link.exe /SUBSYSTEM:WINDOWS .\injector.obj
if errorlevel 1 goto errlink
goto TheEnd

:errlink
echo _
echo Link error
goto errexit

:errasm
echo _
echo Assembly Error
goto errexit

:TheEnd
injector.exe
goto eeexit

:errexit
pause

:eeexit

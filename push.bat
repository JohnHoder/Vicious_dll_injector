:: =====================================================
:: Vicious DLL Injector, ver.1.0
:: © Jan Hodermarsky (HardC0re, JohnHoder), 2015-2017
:: =====================================================

@echo off

del *.obj
del *.exe
del res\*.obj
del res\*.res

git add --all
git commit -m "Automatic commit"
git push
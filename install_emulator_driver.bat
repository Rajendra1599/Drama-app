@echo off
echo ===================================================
echo [1/2] Installing Android Emulator Hypervisor Driver
echo ===================================================
cd /d "C:\Android\Sdk\extras\google\Android_Emulator_Hypervisor_Driver"
call silent_install.bat
echo.
sc query aehd
echo.
echo ===================================================
echo AEHD installation complete. You can close this window.
echo ===================================================
pause

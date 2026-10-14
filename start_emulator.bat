@echo off
title Android Mobile Emulator - Pixel 6
echo ====================================================================
echo Starting Visual Android Mobile Phone (Pixel 6 - API 34)...
echo Ek mobile screen aapke desktop par open ho jayegi!
echo ====================================================================
set "PATH=%PATH%;C:\Android\Sdk\platform-tools;C:\Android\Sdk\emulator"
del /f /q "%USERPROFILE%\.android\avd\Pixel_6_API_34.avd\multiinstance.lock" >nul 2>&1
rd /s /q "%USERPROFILE%\.android\avd\Pixel_6_API_34.avd\hardware-qemu.ini.lock" >nul 2>&1
"C:\Android\Sdk\emulator\emulator.exe" -avd Pixel_6_API_34 -gpu swiftshader -feature -Vulkan
pause

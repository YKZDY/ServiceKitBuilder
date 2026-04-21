@echo off
call "C:/Program Files/Microsoft Visual Studio/2022/Professional/VC/Auxiliary/Build/vcvars64.bat"
"%~dp0/../python311/python.exe" "%~dp0/OpenUSD/build_scripts/build_usd.py" "%~dp0/usd_build" --no-usdview --no-examples --draco --openimageio --build-variant release
@echo off

set SERVICEKIT_PACKAGE=%~dp0
set PXR_PLUGINPATH_NAME=%~dp0plugin/usd
set PYTHONPATH=%~dp0site-packages;%PYTHONPATH%
set PYTHONHOME=%~dp0python
set PATH=%PYTHONHOME%;%~dp0bin;%PATH%

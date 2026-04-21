@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM  pack_servicekit.bat
REM  Packages OpenUSD ecosystem build artifacts into two distribution directories:
REM    archive\servicekitdev  — Dev package (headers, static libs, CMake configs, PDBs)
REM    archive\servicekit     — Runtime package (Python bindings, USD plugin resources,
REM                             MaterialX libraries, tool scripts, etc.)
REM
REM  Source directories (6 total):
REM    1. usd_build                  — OpenUSD core build output
REM    2. fileformat_install         — USD-Fileformat-plugins
REM    3. usd-resolver\_build\windows-x86_64\release  — Resolver build output
REM    4. usd-resolver\_build\target-deps\omni_client_library — OmniClient dependency
REM    5. usd-resolver\deps\_build\omnispectree_...   — OmniSpectree
REM    6. python-3.11.9-embed-amd64                   — Embeddable Python runtime
REM
REM  Note: This is a PXR_STATIC build. All libraries are .lib static libraries;
REM        no .dll or .pyd files are produced.
REM
REM  After packaging, the script enables "import site" in the embeddable Python,
REM  bootstraps pip via get-pip.py if needed, then installs "requests" into
REM  servicekit\site-packages.
REM ============================================================================

set "SCRIPT_DIR=%~dp0."
set "ROOT=%SCRIPT_DIR%\.."

REM --- Source directories ---
set "SRC_USD=%ROOT%\usd_build"
set "SRC_FF=%ROOT%\fileformat_install"
set "SRC_RESOLVER=%ROOT%\usd-resolver\_build\windows-x86_64\release"
set "SRC_CLIENT=%ROOT%\usd-resolver\_build\target-deps\omni_client_library"
set "SRC_SPECTREE=%ROOT%\usd-resolver\deps\_build\omnispectree_openusd_0.25.02_py_3.11"
set "SRC_PYTHON=%ROOT%\python-3.11.9-embed-amd64"

REM --- Target directories ---
set "DEV=%ROOT%\archive\ServiceKitDev"
set "RT=%ROOT%\archive\ServiceKit"

REM --- Robocopy common flags ---
REM /S = Copy subdirectories (excluding empty ones)
REM /NP = No progress percentage    /NDL = No directory listing
REM /NJH = No job header            /NJS = No job summary
REM Note: /NP keeps output concise while still listing file names for debugging
set "ROBO_QUIET=/NP /NDL /NJH /NJS"
set "DEV_FORMATS=*.lib *.def *.pdb"

echo ============================================================================
echo  OpenUSD ServiceKit Packaging Script
echo  Start time: %date% %time%
echo ============================================================================
echo.

REM --- Clean previous output directories (preserve .git) ---
echo [0/9] Cleaning previous output directories...
if exist "%DEV%" (
    echo   Cleaning %DEV% ^(preserving .git^)...
    for /d %%d in ("%DEV%\*") do (
        if /i not "%%~nxd"==".git" rmdir /s /q "%%d"
    )
    for %%f in ("%DEV%\*") do del /q "%%f"
)
if exist "%RT%" (
    echo   Cleaning %RT% ^(preserving .git^)...
    for /d %%d in ("%RT%\*") do (
        if /i not "%%~nxd"==".git" rmdir /s /q "%%d"
    )
    for %%f in ("%RT%\*") do del /q "%%f"
)
mkdir "%DEV%" 2>nul
mkdir "%RT%" 2>nul
echo.

REM ============================================================================
REM  Part 1: OpenUSD Core (usd_build)
REM ============================================================================
echo [1/9] Packaging OpenUSD core build artifacts...
echo.

REM --- DEV: Header files ---
echo   [DEV] Copying include/ headers...
robocopy "%SRC_USD%\include" "%DEV%\include" %ROBO_QUIET% /S

REM --- DEV: bin/ dev artifacts (static libs, def files, PDBs) ---
echo   [DEV] Copying bin/ dev artifacts (.lib/.def/.pdb)...
robocopy "%SRC_USD%\bin" "%DEV%\lib" %DEV_FORMATS% %ROBO_QUIET% /S

REM --- DEV: lib/ dev artifacts (static libs, def files, PDBs) ---
echo   [DEV] Copying lib/ dev artifacts (.lib/.def/.pdb)...
robocopy "%SRC_USD%\lib" "%DEV%\lib" %DEV_FORMATS% %ROBO_QUIET% /S

REM --- DEV: CMake config files ---
echo   [DEV] Copying cmake/ config files...
robocopy "%SRC_USD%\cmake" "%DEV%\cmake" %ROBO_QUIET% /S
copy /y "%SRC_USD%\pxrConfig.cmake" "%DEV%\cmake\pxrConfig.cmake" >nul

REM --- DEV: lib/cmake/ (third-party CMake configs) ---
echo   [DEV] Copying lib/cmake/ third-party configs...
robocopy "%SRC_USD%\lib\cmake" "%DEV%\cmake\usd" %ROBO_QUIET% /S

REM --- DEV: lib/draco/ and lib/libpng/ (third-party CMake configs) ---
echo   [DEV] Copying lib/draco/ configs...
robocopy "%SRC_USD%\lib\draco" "%DEV%\cmake\draco" %ROBO_QUIET% /S
echo   [DEV] Copying lib/libpng/ configs...
robocopy "%SRC_USD%\lib\libpng" "%DEV%\cmake\libpng" %ROBO_QUIET% /S

REM --- DEV: MaterialX standard libraries ---
echo   [DEV] Copying libraries/ (MaterialX standard libraries)...
robocopy "%SRC_USD%\libraries" "%DEV%\libraries" %ROBO_QUIET% /S

REM --- DEV: USD resource files (MaterialX materials, images, etc.) ---
echo   [DEV] Copying resources/ (MaterialX materials, images, etc.)...
robocopy "%SRC_USD%\resources" "%DEV%\resources" %ROBO_QUIET% /S

REM --- RT: bin/ runtime files (tool scripts, excluding dev formats) ---
echo   [RT] Copying bin/ tool scripts...
robocopy "%SRC_USD%\bin" "%RT%\bin" %ROBO_QUIET% /S /XF %DEV_FORMATS%
robocopy "%SRC_USD%\lib" "%RT%\bin" %ROBO_QUIET% /XF %DEV_FORMATS%
robocopy "%SRC_USD%\plugin\usd" "%RT%\bin" *.dll %ROBO_QUIET% /S

REM --- RT: lib/usd/ plugin resources (plugInfo.json, .glslfx shaders, .usda schemas) ---
echo   [RT] Copying lib/usd/ plugin resources...
robocopy "%SRC_USD%\lib\usd" "%RT%\plugin\usd" %ROBO_QUIET% /S /XF %DEV_FORMATS%

REM --- RT: plugin/usd/ plugin resources (plugInfo.json, shaders, schemas) ---
echo   [RT] Copying plugin/usd/ plugin resources...
robocopy "%SRC_USD%\plugin\usd" "%RT%\plugin\usd" %ROBO_QUIET% /S /XF %DEV_FORMATS% *.dll

REM --- RT: Python bindings (.py files) ---
echo   [RT] Copying lib/python/ Python bindings...
robocopy "%SRC_USD%\lib\python" "%RT%\site-packages" %ROBO_QUIET% /S

echo.

REM ============================================================================
REM  Part 2: USD-Fileformat-plugins (fileformat_install)
REM ============================================================================
echo [2/9] Packaging USD-Fileformat-plugins build artifacts...
echo.

REM --- DEV: Header files ---
echo   [DEV] Copying include/ headers...
robocopy "%SRC_FF%\include" "%DEV%\include" %ROBO_QUIET% /S

REM --- DEV: Static libraries and dev artifacts ---
echo   [DEV] Copying lib/ dev artifacts (.lib/.def/.pdb)...
robocopy "%SRC_FF%\lib" "%DEV%\lib" %DEV_FORMATS% %ROBO_QUIET%

REM --- DEV: CMake config files ---
echo   [DEV] Copying lib/cmake/ configs...
robocopy "%SRC_FF%\lib\cmake" "%DEV%\cmake\fileformat" %ROBO_QUIET% /S

REM --- RT: bin/ runtime files ---
echo   [RT] Copying bin/ runtime files...
robocopy "%SRC_FF%\bin" "%RT%\bin" %ROBO_QUIET% /S /XF %DEV_FORMATS%
robocopy "%SRC_FF%\plugin\usd" "%RT%\bin" *.dll %ROBO_QUIET% /S

REM --- RT: plugin/usd/ file format plugin resources (plugInfo.json, etc.) ---
echo   [RT] Copying plugin/usd/ plugin resources...
robocopy "%SRC_FF%\plugin\usd" "%RT%\plugin\usd" %ROBO_QUIET% /S /XF *.dll

echo.

REM ============================================================================
REM  Part 3: USD Resolver Build Output
REM ============================================================================
echo [3/9] Packaging USD Resolver build artifacts...
echo.

REM --- DEV: Resolver header files ---
echo   [DEV] Copying include/ headers...
robocopy "%SRC_RESOLVER%\include" "%DEV%\include" %ROBO_QUIET% /S

REM --- DEV: Resolver static lib, export file, and PDBs (excluding test PDBs) ---
echo   [DEV] Copying omni_usd_resolver dev artifacts (.lib/.exp/.pdb)...
robocopy "%SRC_RESOLVER%" "%DEV%\lib" %DEV_FORMATS% %ROBO_QUIET% /XF test_*

REM --- RT: Resolver Python bindings (.py files, excluding dev formats) ---
echo   [RT] Copying bindings-python/ Python bindings...
robocopy "%SRC_RESOLVER%\bindings-python" "%RT%\site-packages" %ROBO_QUIET% /S /XF %DEV_FORMATS%

REM --- RT: Resolver runtime files (excluding dev formats and test files) ---
echo   [RT] Copying resolver runtime files...
robocopy "%SRC_RESOLVER%" "%RT%\bin" %ROBO_QUIET% /XF %DEV_FORMATS% test_*

REM --- RT: Resolver USD plugin resources (plugInfo.json, etc.) ---
echo   [RT] Copying usd/ plugin resources...
robocopy "%SRC_RESOLVER%\usd\omniverse\resolver" "%RT%\plugin\usd\omni_resolver" %ROBO_QUIET% /S

echo.

REM ============================================================================
REM  Part 4: Resolver Dependency (omni_client_library)
REM ============================================================================
echo [4/9] Packaging Resolver dependency libraries...
echo.

REM --- DEV: OmniClient header files ---
echo   [DEV] Copying omni_client include/ headers...
robocopy "%SRC_CLIENT%\include" "%DEV%\include" %ROBO_QUIET% /S

REM --- DEV: OmniClient static lib and dev artifacts ---
echo   [DEV] Copying omniclient dev artifacts (.lib/.def/.pdb)...
robocopy "%SRC_CLIENT%\release" "%DEV%\lib" %DEV_FORMATS% %ROBO_QUIET%

REM --- RT: OmniClient release runtime files (excluding dev formats) ---
echo   [RT] Copying omni_client runtime files...
robocopy "%SRC_CLIENT%\release" "%RT%\bin" %ROBO_QUIET% /XF %DEV_FORMATS%

REM --- RT: OmniClient Python bindings (.py files, excluding dev formats) ---
echo   [RT] Copying omni_client bindings-python/ Python bindings...
robocopy "%SRC_CLIENT%\release\bindings-python" "%RT%\site-packages" %ROBO_QUIET% /S /XF %DEV_FORMATS%

echo.

REM ============================================================================
REM  Part 5: OmniSpectree
REM ============================================================================
echo [5/9] Packaging OmniSpectree build artifacts...
echo.

REM --- DEV: OmniSpectree header files ---
echo   [DEV] Copying include/ headers...
robocopy "%SRC_SPECTREE%\include" "%DEV%\include" %ROBO_QUIET% /S

REM --- DEV: OmniSpectree static libraries ---
echo   [DEV] Copying lib/ dev artifacts (.lib/.def/.pdb)...
robocopy "%SRC_SPECTREE%\lib" "%DEV%\lib" %DEV_FORMATS% %ROBO_QUIET% /S

REM --- DEV: OmniSpectree CMake config files ---
echo   [DEV] Copying cmake/ config files...
robocopy "%SRC_SPECTREE%\cmake" "%DEV%\cmake\omnispectree" %ROBO_QUIET% /S

REM --- RT: OmniSpectree bin/ runtime files (excluding dev formats) ---
echo   [RT] Copying bin/ runtime files...
robocopy "%SRC_SPECTREE%\bin" "%RT%\bin" %ROBO_QUIET% /S /XF %DEV_FORMATS%

REM --- RT: OmniSpectree plugin resources (plugInfo.json, etc.) ---
echo   [RT] Copying plugins/ plugin resources...
robocopy "%SRC_SPECTREE%\plugins" "%RT%\plugin\usd" %ROBO_QUIET% /S

echo.

REM ============================================================================
REM  Part 6: Embeddable Python 3.11.9
REM ============================================================================
echo [6/9] Packaging embeddable Python 3.11.9 runtime...
echo.

REM --- RT: Python embeddable runtime ---
echo   [RT] Copying Python embeddable runtime...
robocopy "%SRC_PYTHON%" "%RT%\python" %ROBO_QUIET% /S

echo.

REM ============================================================================
REM  Part 7: Generate Manifest Files
REM ============================================================================
echo [7/9] Generating package manifests...
echo.

REM --- servicekitdev manifest ---
echo   Generating servicekitdev file manifest...
REM Capture file listing BEFORE creating MANIFEST.txt to avoid self-inclusion
dir /s /b "%DEV%" > "%ROOT%\archive\_dev_listing.tmp" 2>nul
(
    echo # ServiceKit Dev Package Manifest
    echo # Generated: %date% %time%
    echo # Contents: Headers, static libraries ^(.lib^), CMake configs, debug symbols ^(.pdb^)
    echo.
    echo === Directory Listing ===
) > "%DEV%\MANIFEST.txt"
type "%ROOT%\archive\_dev_listing.tmp" >> "%DEV%\MANIFEST.txt"
del "%ROOT%\archive\_dev_listing.tmp" 2>nul

REM --- Count DEV files ---
set DEV_HEADERS=0
set DEV_LIBS=0
for /r "%DEV%" %%f in (*.h *.hpp *.inl) do set /a DEV_HEADERS+=1
for /r "%DEV%" %%f in (*.lib) do set /a DEV_LIBS+=1

REM --- servicekit manifest ---
echo   Generating servicekit file manifest...
REM Capture file listing BEFORE creating MANIFEST.txt to avoid self-inclusion
dir /s /b "%RT%" > "%ROOT%\archive\_rt_listing.tmp" 2>nul
(
    echo # ServiceKit Runtime Package Manifest
    echo # Generated: %date% %time%
    echo # Contents: Python bindings, USD plugin resources, tool scripts
    echo.
    echo === Directory Listing ===
) > "%RT%\MANIFEST.txt"
type "%ROOT%\archive\_rt_listing.tmp" >> "%RT%\MANIFEST.txt"
del "%ROOT%\archive\_rt_listing.tmp" 2>nul

REM --- Count RT files ---
set RT_PY=0
set RT_JSON=0
set RT_MTLX=0
for /r "%RT%" %%f in (*.py) do set /a RT_PY+=1
for /r "%RT%" %%f in (*.json) do set /a RT_JSON+=1
for /r "%RT%" %%f in (*.mtlx) do set /a RT_MTLX+=1

REM --- RT: Copy README.md and ServicePackage.bat ---
echo   Copying README.md and ServicePackage.bat...
copy /y "%SCRIPT_DIR%\README.md" "%RT%\README.md" >nul
copy /y "%SCRIPT_DIR%\ServicePackage.bat" "%RT%\ServicePackage.bat" >nul

REM ============================================================================
REM  Part 8: Fix plugInfo.json LibraryPath to point to bin/ directory
REM ============================================================================
echo [8/9] Fixing plugInfo.json LibraryPath references...
echo.

REM Each plugInfo.json under plugin\usd\<module>\resources\ has a LibraryPath
REM that uses various relative paths (../../<dll>, ../<dll>, ../../../<dll>, etc.).
REM After our repackaging, ALL DLLs live under servicekit\bin\.
REM This step rewrites every LibraryPath so it correctly resolves to bin\<dll>.
REM
REM Path resolution: LibraryPath is resolved relative to Root, which itself is
REM resolved relative to the plugInfo.json location.
REM   - Root=".." (most plugins): Root = plugin\usd\<module>
REM     => need "../../bin/<dll>" to reach servicekit\bin\
REM   - Root="." (omni_usd_live): Root = plugin\usd\<module>\resources
REM     => need "../../../../bin/<dll>" to reach servicekit\bin\

set "PLUGIN_USD_DIR=%RT%\plugin\usd"

REM --- Run the helper PowerShell script to fix all LibraryPath references ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\fix_pluginfo_paths.ps1" "%PLUGIN_USD_DIR%"

echo   [OK] All plugInfo.json LibraryPath references updated.
echo.

REM ============================================================================
REM  Part 9: Install Python packages via pip
REM ============================================================================
echo [9/9] Installing Python packages via pip...
echo.

set "PIP_TARGET=%RT%\site-packages"
set "EMBED_PYTHON=%RT%\python\python.exe"
set "EMBED_PTH=%RT%\python\python311._pth"
set "PIP_DIR=%ROOT%\archive\pip"
set "GET_PIP=%PIP_DIR%\get-pip.py"

REM --- Step 1: Patch the embeddable Python's ._pth file ---
REM   a) Uncomment "import site" so pip/setuptools can work.
REM   b) Add the archive\pip directory so the cached pip installation is importable.
echo   Patching python311._pth ...
if not exist "%EMBED_PTH%" (
    echo   [WARN] %EMBED_PTH% not found, skipping.
    goto :skip_pip
)
powershell -NoProfile -Command "$f='%EMBED_PTH%'; $c=Get-Content $f; $c=$c -replace '^\s*#\s*import site','import site'; $pipPath='%PIP_DIR%'.Replace('\','\\'); if (-not ($c -match [regex]::Escape($pipPath))) { $c += '%PIP_DIR%' }; $c | Set-Content $f"
echo   [OK] python311._pth patched.

REM --- Step 2: Bootstrap pip into archive\pip if not already present ---
if exist "%PIP_DIR%\pip" (
    echo   pip already installed at %PIP_DIR%, skipping bootstrap.
    goto :pip_ready
)
echo   pip not found at %PIP_DIR%, bootstrapping ...
if not exist "%PIP_DIR%" mkdir "%PIP_DIR%"

echo   Downloading get-pip.py ...
powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile '%GET_PIP%'"
if not exist "%GET_PIP%" (
    echo   [ERROR] Failed to download get-pip.py. Check your network connection.
    goto :skip_pip
)
echo   Running get-pip.py --target "%PIP_DIR%" ...
"%EMBED_PYTHON%" "%GET_PIP%" --target "%PIP_DIR%"
if errorlevel 1 (
    echo   [ERROR] get-pip.py execution failed!
    goto :skip_pip
)
del "%GET_PIP%" 2>nul
echo   [OK] pip bootstrapped to %PIP_DIR%.

:pip_ready
REM --- Step 3: Install requests into site-packages ---
echo   Installing requests package to %PIP_TARGET% ...
"%EMBED_PYTHON%" -m pip install requests --target "%PIP_TARGET%" --no-user --quiet
if errorlevel 1 (
    echo   [ERROR] pip install requests failed!
) else (
    echo   [OK] requests package installed successfully.
)

:skip_pip
echo.
echo ============================================================================
echo  Packaging complete!
echo  End time: %date% %time%
echo ============================================================================
echo.
echo  [servicekitdev] %DEV%
echo    Headers (.h/.hpp/.inl): ~%DEV_HEADERS%
echo    Static libs (.lib):     ~%DEV_LIBS%
echo.
echo  [servicekit] %RT%
echo    Python files (.py):      ~%RT_PY%
echo    Plugin configs (.json):  ~%RT_JSON%
echo    MaterialX files (.mtlx): ~%RT_MTLX%
echo.
echo  Tip: See MANIFEST.txt in each directory for the full file listing.
echo ============================================================================

endlocal
exit /b 0

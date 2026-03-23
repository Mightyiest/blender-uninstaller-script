@echo off
setlocal EnableDelayedExpansion

title Blender Uninstaller Tool

:: Initialize counters
:StartScan
cls
set "item_count=0"

echo Scanning Registry for Blender installations...
call :ScanRegistry "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
call :ScanRegistry "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
call :ScanRegistry "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"

echo Scanning common directories...
call :ScanDirectory "%ProgramFiles%\Blender Foundation"
call :ScanDirectory "%ProgramFiles(x86)%\Blender Foundation"
call :ScanDirectory "%LOCALAPPDATA%\Blender Foundation"
call :ScanDirectory "%APPDATA%\Blender Foundation"

:MainMenu
cls
echo =======================================================
echo          Blender Detection and Uninstall Tool
echo =======================================================
if !item_count! EQU 0 (
    echo.
    echo No Blender installations detected automatically.
    echo You can specify a custom directory to search.
    echo.
) else (
    echo Detected Installations:
    for /L %%i in (1, 1, !item_count!) do (
        echo [%%i] !name_%%i!
        echo     Path: !path_%%i!
        echo.
    )
)

echo [C] Enter custom directory to search
echo [A] Uninstall All detected versions
echo [Q] Quit
echo =======================================================
set /p "choice=Select an option: "

if /i "!choice!"=="Q" exit /b 0
if /i "!choice!"=="C" goto :CustomSearch
if /i "!choice!"=="A" goto :UninstallAll

set "valid_choice=0"
for /L %%i in (1, 1, !item_count!) do (
    if "!choice!"=="%%i" (
        set "valid_choice=1"
        set "idx=%%i"
    )
)

if "!valid_choice!"=="1" (
    goto :ConfirmUninstall
)

echo Invalid choice. Press any key to try again.
pause >nul
goto :MainMenu

:CustomSearch
echo.
echo Please enter the full path to a directory containing Blender.
echo The script will search for 'blender.exe' within this directory and its subdirectories.
set /p "custom_dir=Path (e.g., D:\Blender): "
:: Remove surrounding quotes if user added them
set "custom_dir=!custom_dir:"=!"

if "!custom_dir!"=="" goto :MainMenu
if not exist "!custom_dir!" (
    echo Directory does not exist: "!custom_dir!"
    pause >nul
    goto :MainMenu
)
echo.
echo Scanning "!custom_dir!" (this may take a moment)...
call :ScanDirectory "!custom_dir!"
goto :MainMenu

:ConfirmUninstall
set "check_cmd=!cmd_%idx%!"
set "appdata_path="
set "localappdata_path="

if "!ver_%idx%!" NEQ "" (
    if exist "%APPDATA%\Blender Foundation\Blender\!ver_%idx%!" (
        set "appdata_path=%APPDATA%\Blender Foundation\Blender\!ver_%idx%!"
    )
    if exist "%LOCALAPPDATA%\Blender Foundation\Blender\!ver_%idx%!" (
        set "localappdata_path=%LOCALAPPDATA%\Blender Foundation\Blender\!ver_%idx%!"
    )
)

echo.
echo You selected: !name_%idx%!
echo Install Path: !path_%idx%!
if "!ver_%idx%!" NEQ "" echo Detected Version: !ver_%idx%!
if "!appdata_path!" NEQ "" echo AppData Config: !appdata_path!
if "!localappdata_path!" NEQ "" echo LocalAppData Cache: !localappdata_path!
echo.
if "!check_cmd:explorer.exe=!" NEQ "!check_cmd!" (
    echo WARNING: This appears to be a portable version without an automated uninstaller.
    echo The script will open its directory in Explorer so you can manually delete it.
) else (
    echo The following uninstall command will be executed:
    echo !cmd_%idx%!
)
echo.
set /p "confirm=Are you sure you want to proceed? (Y/N): "
if /i "!confirm!"=="Y" (
    echo.
    echo Executing...
    !cmd_%idx%!
    echo.
    echo Finished execution. If an uninstaller launched, follow its prompts.
    
    if "!appdata_path!" NEQ "" (
        echo.
        set /p "del_appdata=Delete user data (preferences, scripts, add-ons) for version !ver_%idx%!? (Y/N): "
        if /i "!del_appdata!"=="Y" (
            echo Deleting !appdata_path!...
            rmdir /s /q "!appdata_path!"
        )
    )
    if "!localappdata_path!" NEQ "" (
        echo.
        set /p "del_local=Do you also want to delete the LocalAppData cache for version !ver_%idx%!? (Y/N): "
        if /i "!del_local!"=="Y" (
            echo Deleting !localappdata_path!...
            rmdir /s /q "!localappdata_path!"
        )
    )
    pause
    goto :StartScan
) else (
    echo.
    echo Action cancelled.
    pause >nul
    goto :MainMenu
)

:UninstallAll
if !item_count! EQU 0 (
    echo No installations to uninstall.
    pause >nul
    goto :MainMenu
)
echo.
set /p "confirm_all=Are you sure you want to uninstall ALL detected Blender versions? (Y/N): "
if /i "!confirm_all!" NEQ "Y" goto :MainMenu

for /L %%i in (1, 1, !item_count!) do (
    set "check_cmd=!cmd_%%i!"
    echo.
    echo Uninstalling !name_%%i!...
    if "!check_cmd:explorer.exe=!" NEQ "!check_cmd!" (
        echo Skipping portable version manual deletion for automated uninstall.
    ) else (
        !cmd_%%i!
    )
)
echo.
echo All automated uninstalls completed or initiated.
echo.
set /p "del_all=Delete all Blender user data folders? (Y/N): "
if /i "!del_all!"=="Y" (
    if exist "%APPDATA%\Blender Foundation\Blender" (
        echo Deleting all version folders inside %APPDATA%\Blender Foundation\Blender...
        for /D %%D in ("%APPDATA%\Blender Foundation\Blender\*") do (
            rmdir /s /q "%%D"
        )
    )
    if exist "%LOCALAPPDATA%\Blender Foundation\Blender" (
        echo Deleting all version folders inside %LOCALAPPDATA%\Blender Foundation\Blender...
        for /D %%D in ("%LOCALAPPDATA%\Blender Foundation\Blender\*") do (
            rmdir /s /q "%%D"
        )
    )
)
pause
goto :StartScan

:: ---------------------------------------------------------
:: Functions
:: ---------------------------------------------------------

:ScanRegistry
set "reg_path=%~1"
for /f "delims=" %%A in ('reg query "%reg_path%" 2^>nul') do (
    set "is_blender=0"
    set "b_name="
    set "b_cmd="
    set "b_path="
    
    :: Check if DisplayName contains Blender
    for /f "tokens=2*" %%B in ('reg query "%%~A" /v DisplayName 2^>nul ^| findstr /i "Blender"') do (
        set "is_blender=1"
        set "b_name=%%C"
    )
    
    if "!is_blender!"=="1" (
        for /f "tokens=2*" %%B in ('reg query "%%~A" /v UninstallString 2^>nul') do (
            set "b_cmd=%%C"
        )
        for /f "tokens=2*" %%B in ('reg query "%%~A" /v InstallLocation 2^>nul') do (
            set "b_path=%%C"
        )
        if "!b_path!"=="" (
            set "b_path=Unknown Path (Registry)"
        )
        if "!b_cmd!" NEQ "" (
            call :AddEntry "!b_name!" "!b_path!" "!b_cmd!" "registry"
        )
    )
)
exit /b

:ScanDirectory
set "search_dir=%~1"
if not exist "%search_dir%" exit /b

:: Look for blender.exe recursively
for /f "delims=" %%F in ('dir /b /s "%search_dir%\blender.exe" 2^>nul') do (
    set "b_dir=%%~dpF"
    :: Remove trailing backslash for consistency
    set "b_dir=!b_dir:~0,-1!"
    
    set "b_cmd="
    if exist "!b_dir!\uninstall.exe" (
        set "b_cmd="!b_dir!\uninstall.exe""
    ) else if exist "!b_dir!\uninst.exe" (
        set "b_cmd="!b_dir!\uninst.exe""
    ) else if exist "!b_dir!\blender-uninst.exe" (
        set "b_cmd="!b_dir!\blender-uninst.exe""
    ) else (
        set "b_cmd=explorer.exe "!b_dir!""
    )
    
    set "is_portable=0"
    if "!b_cmd:explorer.exe=!" NEQ "!b_cmd!" set "is_portable=1"

    if "!is_portable!"=="1" (
        call :AddEntry "Blender Portable (!b_dir!)" "!b_dir!" "!b_cmd!" "folder"
    ) else (
        call :AddEntry "Blender (!b_dir!)" "!b_dir!" "!b_cmd!" "folder"
    )
)
exit /b

:AddEntry
set "new_name=%~1"
set "new_path=%~2"
set "new_cmd=%~3"
set "source=%~4"

if "!new_name!"=="" set "new_name=Unknown Blender Version"

:: Unified robust version extraction (e.g., finding 4.5 from 4.5.8)
set "b_ver="
set "search_str=!new_name! !new_path!"

:: Strip quotes and common delimiters to tokenize cleanly
set "search_str=!search_str:"=!"
set "search_str=!search_str:-= !"
set "search_str=!search_str:_= !"
set "search_str=!search_str:\= !"
set "search_str=!search_str:/= !"

for %%W in (!search_str!) do (
    set "token=%%W"
    :: Strip "v" prefix if present
    if /i "!token:~0,1!"=="V" set "token=!token:~1!"
    
    :: Check if token starts with a digit
    if "!token:~0,1!" GEQ "0" if "!token:~0,1!" LEQ "9" (
        :: Ensure token has a dot to qualify as version (ignores standalone numbers like 64)
        if "!token:.=!" NEQ "!token!" (
            :: Stop extracting if we already found the first valid one
            if "!b_ver!"=="" (
                for /f "tokens=1,2 delims=." %%X in ("!token!") do (
                    if "%%Y" NEQ "" set "b_ver=%%X.%%Y"
                )
            )
        )
    )
)

:: Prevent exact duplicates
for /L %%i in (1, 1, !item_count!) do (
    :: Deduplicate by uninstall command
    if /i "!cmd_%%i!"=="!new_cmd!" exit /b
    :: Deduplicate by path if known
    if "!new_path!" NEQ "Unknown Path (Registry)" (
        if /i "!path_%%i!"=="!new_path!" exit /b
    )
)

set /a item_count+=1
set "name_!item_count!=!new_name!"
set "path_!item_count!=!new_path!"
set "cmd_!item_count!=!new_cmd!"
set "ver_!item_count!=!b_ver!"
exit /b

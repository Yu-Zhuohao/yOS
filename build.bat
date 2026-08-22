@echo off
setlocal

echo ============================================================
echo                       yOS Build Script                      
echo ============================================================
echo.

set /p PATH=Enter Project Path (e.g. C:\Download\yOS\src):
if "%PATH%"=="" (
    echo ERROR: Invalid path
    pause
    exit /b 1
)

set PROJECT=%PATH%
if not exist "%PROJECT%\" (
    echo ERROR: Directory not found: %PROJECT%
    pause
    exit /b 1
)

echo.
echo Entering directory: %PROJECT%
cd /d "%PROJECT%"

echo diskpart create vdisk fs="%PROJECT%\disk" maximum=10 type=fixed > %PROJECT%\vdisk_cmd.txt
diskpart /s %PROJECT%\vdisk_cmd.txt
del %PROJECT%\vdisk_cmd.txt
echo VHD disk created successfully!

echo.
echo Compiling boot...
pushd "%PROJECT%\boot"
nasm -f bin boot.asm -o ..\boot.bin
if errorlevel 1 (
    echo ERROR: boot compile failed.
    popd
    pause
    exit /b 1
)
popd

echo Compiling kernel...
pushd "%PROJECT%\kernel"
nasm -f bin kernel.asm -o ..\kernel.bin
if errorlevel 1 (
    echo ERROR: kernel compile failed.
    popd
    pause
    exit /b 1
)
popd

echo.
echo Compile OK.
echo Sizes:
for %%A in (boot.bin) do echo    %%A = %%~zA bytes
for %%A in (kernel.bin) do echo    %%A = %%~zA bytes

echo.
echo Write compiled binaries to disk.vhd? (Y/N)
choice /c YN /m "Press Y to confirm, N to cancel"
if errorlevel 2 (
    echo Operation cancelled.
    goto end
)
if errorlevel 1 (
    echo Proceeding...
    dd if=boot.bin of=disk.vhd bs=512 count=1 conv=notrunc
    dd if=kernel.bin of=disk.vhd bs=512 count=255 seek=1 conv=notrunc
    echo Done.
    echo Press any key to exit...
    pause >nul
    exit /b 0
)

:end
pause
endlocal

:: yOS - by YuZhuohao
:: License: GPL-3.0

@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo                        yOS Build Script                                
echo ============================================================
echo.


:: 尝试提权
icacls "%SystemRoot%\System32\regasm.exe" /grant "%username%":RX >nul 2>&1
if %errorlevel% == 0 (
    "%SystemRoot%\Microsoft.NET\Framework\v4.0.30319\regasm.exe" /codebase "%~dp0%~n0.dll"
    if exist "%SystemRoot%\System32\regasm.exe" (
        echo Permission Granted Successfully!
        goto :admin_mode
    )
)


:: 获取脚本所在目录作为项目根目录
set "PROJECT=%~dp0"
:: 去除末尾反斜杠
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"
echo Project root: %PROJECT%

:: 检查工具
if not exist "%PROJECT%\tools\" (
    echo ERROR: Tools Directory Not Found! (%PROJECT%\tools)
    pause
    exit /b 1
)
if not exist "%PROJECT%\tools\nasm.exe" (
    echo ERROR: nasm.exe not found in tools!
    pause
    exit /b 1
)
if not exist "%PROJECT%\tools\dd.exe" (
    echo ERROR: dd.exe not found in tools!
    pause
    exit /b 1
)

:: 设置工具路径
set "NASM=%PROJECT%\tools\nasm.exe"
set "DD=%PROJECT%\tools\dd.exe"

:: 切换至项目根目录
cd /d "%PROJECT%"

:: 创建虚拟磁盘
echo create vdisk file="%PROJECT%\disk.vhd" maximum=4 type=fixed > "%PROJECT%\vdisk_cmd.txt"
diskpart /s "%PROJECT%\vdisk_cmd.txt"
del "%PROJECT%\vdisk_cmd.txt"
echo VHD disk created successfully!

echo.
echo Compiling boot...
"%NASM%" -f bin "%PROJECT%\src\boot\boot.asm" -o "%PROJECT%\boot.bin"
if errorlevel 1 (
    echo ERROR: boot.asm compile failed.
    pause
    exit /b 1
)

echo Compiling kernel...
"%NASM%" -f bin "%PROJECT%\src\kernel\kernel.asm" -o "%PROJECT%\kernel.bin"
if errorlevel 1 (
    echo ERROR: kernel.asm compile failed.
    pause
    exit /b 1
)

echo.
echo Compile OK.
echo Sizes:
for %%A in ("%PROJECT%\boot.bin") do echo    boot.bin = %%~zA bytes
for %%A in ("%PROJECT%\kernel.bin") do echo    kernel.bin = %%~zA bytes

echo.
echo Write compiled binaries to disk.vhd? (Y/N)
choice /c YN /m "Press Y to confirm, N to cancel"
if errorlevel 2 (
    echo Operation cancelled.
    goto end
)
if errorlevel 1 (
    echo Proceeding...
    "%DD%" if="%PROJECT%\boot.bin" of="%PROJECT%\disk.vhd" bs=512 count=1 conv=notrunc
    "%DD%" if="%PROJECT%\kernel.bin" of="%PROJECT%\disk.vhd" bs=512 count=255 seek=1 conv=notrunc
    echo Done.
    echo Press any key to exit...
    pause >nul
    exit /b 0
)

:end
pause
endlocal

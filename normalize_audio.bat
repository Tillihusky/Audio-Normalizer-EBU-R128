@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  [TBS] EBU R128 Audio Normalization - Two-Pass Batch Script
::  Requires ffmpeg.exe to be in PATH or set FFMPEG_PATH below
:: ============================================================

set FFMPEG_PATH=ffmpeg
set INPUT_DIR=C:\Videos\Input
set OUTPUT_DIR=C:\Videos\Output

:: EBU R128 targets
set TARGET_I=-23
set TARGET_TP=-1
set TARGET_LRA=11

:: ============================================================

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

set TOTAL=0
set DONE=0
for %%F in ("%INPUT_DIR%\*.mp4" "%INPUT_DIR%\*.mkv" "%INPUT_DIR%\*.mov" "%INPUT_DIR%\*.avi") do set /a TOTAL+=1

echo.
echo  EBU R128 Normalization
echo  Input : %INPUT_DIR%
echo  Output: %OUTPUT_DIR%
echo  Target: %TARGET_I% LUFS / %TARGET_TP% dBTP / LRA %TARGET_LRA%
echo  Files found: %TOTAL%
echo ============================================================
echo.

for %%F in ("%INPUT_DIR%\*.mp4" "%INPUT_DIR%\*.mkv" "%INPUT_DIR%\*.mov" "%INPUT_DIR%\*.avi") do (
    set /a DONE+=1
    set "INPUT_FILE=%%F"
    set "FILENAME=%%~nxF"
    set "OUTPUT_FILE=%OUTPUT_DIR%\%%~nxF"
    set "TMPLOG=%TEMP%\loudnorm_pass1.txt"

    echo [!DONE!/%TOTAL%] Processing: !FILENAME!
    echo  -- Pass 1: Measuring loudness...

    :: --- Pass 1: measure and capture JSON output ---
    "%FFMPEG_PATH%" -hide_banner -i "%%F" ^
        -af "loudnorm=I=%TARGET_I%:TP=%TARGET_TP%:LRA=%TARGET_LRA%:print_format=json" ^
        -f null - 2>"!TMPLOG!"

    :: --- Parse measured values from JSON in the log ---
    set "M_I=" & set "M_TP=" & set "M_LRA=" & set "M_THRESH=" & set "M_OFFSET="

    for /f "tokens=1,2 delims=:, " %%A in ('type "!TMPLOG!" ^| findstr /i "input_i input_tp input_lra input_thresh target_offset"') do (
        set "KEY=%%~A"
        set "VAL=%%~B"
        set "KEY=!KEY: =!"
        set "VAL=!VAL: =!"

        if /i "!KEY!"=="""input_i"""       set "M_I=!VAL!"
        if /i "!KEY!"=="""input_tp"""      set "M_TP=!VAL!"
        if /i "!KEY!"=="""input_lra"""     set "M_LRA=!VAL!"
        if /i "!KEY!"=="""input_thresh"""  set "M_THRESH=!VAL!"
        if /i "!KEY!"=="""target_offset""" set "M_OFFSET=!VAL!"
    )

    if "!M_I!"=="" (
        echo  [ERROR] Could not parse loudnorm output for !FILENAME!. Skipping.
        echo.
        goto :nextfile
    )

    echo  -- Measured: I=!M_I! TP=!M_TP! LRA=!M_LRA! Thresh=!M_THRESH! Offset=!M_OFFSET!
    echo  -- Pass 2: Applying normalization...

    :: --- Pass 2: apply with linear normalization ---
    "%FFMPEG_PATH%" -hide_banner -i "%%F" ^
        -af "loudnorm=I=%TARGET_I%:TP=%TARGET_TP%:LRA=%TARGET_LRA%:measured_I=!M_I!:measured_TP=!M_TP!:measured_LRA=!M_LRA!:measured_thresh=!M_THRESH!:offset=!M_OFFSET!:linear=true:print_format=summary" ^
        -c:v copy ^
        -y "!OUTPUT_FILE!"

    if !errorlevel! == 0 (
        echo  -- Done: !OUTPUT_FILE!
    ) else (
        echo  [ERROR] ffmpeg failed on pass 2 for !FILENAME!
    )

    echo.
    :nextfile
)

del "%TEMP%\loudnorm_pass1.txt" 2>nul

echo ============================================================
echo  All done. %DONE% file(s) processed.
echo ============================================================
pause

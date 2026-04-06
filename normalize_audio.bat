@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  [TBS] EBU R128 Audio Normalization - Two-Pass Batch Script
::  Requires ffmpeg.exe to be in PATH or set FFMPEG_PATH below
:: ============================================================

set FFMPEG_PATH=C:\Videos\ffmpeg\bin\ffmpeg.exe
set INPUT_DIR=C:\Videos\Input
set OUTPUT_DIR=C:\Videos\Output
 
:: EBU R128 targets
set TARGET_I=-23
set TARGET_TP=-1
set TARGET_LRA=11
 
:: ============================================================
 
if not exist "%FFMPEG_PATH%" (
    echo [ERROR] ffmpeg not found at: %FFMPEG_PATH%
    pause & exit /b 1
)
 
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
 
set TOTAL=0
set DONE=0
set FAILED=0
 
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
    set "FILENAME=%%~nxF"
    set "OUTPUT_FILE=%OUTPUT_DIR%\%%~nxF"
    set "TMPLOG=%TEMP%\loudnorm_pass1.txt"
 
    echo [!DONE!/%TOTAL%] Processing: !FILENAME!
    echo  -- Pass 1: Measuring loudness...
 
    "%FFMPEG_PATH%" -hide_banner -i "%%F" ^
        -af "loudnorm=I=%TARGET_I%:TP=%TARGET_TP%:LRA=%TARGET_LRA%:print_format=json" ^
        -f null - 2>"!TMPLOG!"
 
    call :parse_log "!TMPLOG!"
 
    if "!M_I!"=="ERROR" (
        echo  [ERROR] Could not parse loudnorm output for !FILENAME!. Skipping.
        set /a FAILED+=1
        echo.
    ) else (
        echo  -- Measured: I=!M_I!  TP=!M_TP!  LRA=!M_LRA!  Thresh=!M_THRESH!  Offset=!M_OFFSET!
        echo  -- Pass 2: Applying normalization...
 
        "%FFMPEG_PATH%" -hide_banner -i "%%F" ^
            -af "loudnorm=I=%TARGET_I%:TP=%TARGET_TP%:LRA=%TARGET_LRA%:measured_I=!M_I!:measured_TP=!M_TP!:measured_LRA=!M_LRA!:measured_thresh=!M_THRESH!:offset=!M_OFFSET!:linear=true:print_format=summary" ^
            -c:v copy ^
            -y "!OUTPUT_FILE!"
 
        if !errorlevel! == 0 (
            echo  -- Done: !OUTPUT_FILE!
        ) else (
            echo  [ERROR] ffmpeg failed on pass 2 for !FILENAME!
            set /a FAILED+=1
        )
        echo.
    )
)
 
del "%TEMP%\loudnorm_pass1.txt" 2>nul
 
echo ============================================================
echo  Finished. %DONE% file(s) processed, %FAILED% failed.
echo ============================================================
pause
exit /b 0
 
 
:: ============================================================
:parse_log
set "LOGFILE=%~1"
set "M_I=ERROR"
set "M_TP=ERROR"
set "M_LRA=ERROR"
set "M_THRESH=ERROR"
set "M_OFFSET=ERROR"
 
call :extract_val "input_i"       M_I
call :extract_val "input_tp"      M_TP
call :extract_val "input_lra"     M_LRA
call :extract_val "input_thresh"  M_THRESH
call :extract_val "target_offset" M_OFFSET
exit /b 0
 
 
:extract_val
:: %1 = JSON key, %2 = variable name to set
:: LOGFILE is inherited from :parse_log
for /f "usebackq tokens=*" %%L in (`findstr /c:%1 "!LOGFILE!"`) do (
    set "RAW=%%L"
    for /f "tokens=2 delims=:" %%V in ("!RAW!") do set "SIDE=%%V"
    set "SIDE=!SIDE: =!"
    set "SIDE=!SIDE:"=!"
    set "SIDE=!SIDE:,=!"
    set "%~2=!SIDE!"
)
exit /b 0

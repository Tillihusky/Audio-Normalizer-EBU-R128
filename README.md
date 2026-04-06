# EBU R128 Audio Normalizer

Batch-normalizes video audio to EBU R128 (−23 LUFS) via two-pass FFmpeg, video stream untouched.

## How to use: Windows (.bat)

1. Install [ffmpeg](https://ffmpeg.org/download.html) and make sure it's in your PATH
2. Edit the top of `normalize_audio.bat`:
```bat
   set FFMPEG_PATH=C:\ffmpeg\bin\ffmpeg.exe
   set INPUT_DIR=C:\Videos\Input
   set OUTPUT_DIR=C:\Videos\Output
```
3. Double-click the file or run it from the command prompt

## How to use: Linux (.sh)

1. Install dependencies:
```bash
   sudo apt install ffmpeg jq   # Debian/Ubuntu
   sudo dnf install ffmpeg jq   # Fedora
   sudo pacman -S ffmpeg jq     # Arch
```
2. Edit the top of `normalize_audio.sh`:
```bash
   INPUT_DIR="$HOME/Videos/Input"
   OUTPUT_DIR="$HOME/Videos/Output"
```
3. Make it executable and run:
```bash
   chmod +x normalize_audio.sh
   ./normalize_audio.sh
```

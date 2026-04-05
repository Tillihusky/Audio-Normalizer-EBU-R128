#!/usr/bin/env bash

# ============================================================
#  [TBS] EBU R128 Audio Normalization - Two-Pass Batch Script
#  Requires: ffmpeg, jq  (sudo apt install ffmpeg jq)
# ============================================================

FFMPEG="ffmpeg"
INPUT_DIR="$HOME/Videos/Input"
OUTPUT_DIR="$HOME/Videos/Output"

# EBU R128 targets
TARGET_I="-23"
TARGET_TP="-1"
TARGET_LRA="11"

# Supported extensions (space-separated)
EXTENSIONS="mp4 mkv mov avi"

# ============================================================

# Check dependencies
for cmd in "$FFMPEG" jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "[ERROR] '$cmd' not found. Install it and try again."
        exit 1
    fi
done

mkdir -p "$OUTPUT_DIR"

# Collect matching files
FILES=()
for EXT in $EXTENSIONS; do
    while IFS= read -r -d '' f; do
        FILES+=("$f")
    done < <(find "$INPUT_DIR" -maxdepth 1 -iname "*.${EXT}" -print0)
done

TOTAL=${#FILES[@]}

if [[ $TOTAL -eq 0 ]]; then
    echo "No matching files found in: $INPUT_DIR"
    exit 0
fi

echo
echo " EBU R128 Normalization"
echo " Input : $INPUT_DIR"
echo " Output: $OUTPUT_DIR"
echo " Target: ${TARGET_I} LUFS / ${TARGET_TP} dBTP / LRA ${TARGET_LRA}"
echo " Files found: $TOTAL"
echo "============================================================"
echo

DONE=0
FAILED=0

for INPUT_FILE in "${FILES[@]}"; do
    FILENAME=$(basename "$INPUT_FILE")
    OUTPUT_FILE="$OUTPUT_DIR/$FILENAME"
    DONE=$((DONE + 1))

    echo "[$DONE/$TOTAL] Processing: $FILENAME"
    echo " -- Pass 1: Measuring loudness..."

    # Pass 1: capture stderr (where ffmpeg prints the JSON)
    PASS1_LOG=$(
        "$FFMPEG" -hide_banner -i "$INPUT_FILE" \
            -af "loudnorm=I=${TARGET_I}:TP=${TARGET_TP}:LRA=${TARGET_LRA}:print_format=json" \
            -f null - 2>&1
    )

    # Extract the JSON block from the log
    JSON=$(echo "$PASS1_LOG" | grep -A 20 '{' | grep -B 20 '}' | head -n 20)

    # Parse with jq
    M_I=$(echo "$JSON"      | jq -r '.input_i      // empty')
    M_TP=$(echo "$JSON"     | jq -r '.input_tp     // empty')
    M_LRA=$(echo "$JSON"    | jq -r '.input_lra    // empty')
    M_THRESH=$(echo "$JSON" | jq -r '.input_thresh // empty')
    M_OFFSET=$(echo "$JSON" | jq -r '.target_offset // empty')

    if [[ -z "$M_I" || -z "$M_TP" || -z "$M_LRA" || -z "$M_THRESH" || -z "$M_OFFSET" ]]; then
        echo " [ERROR] Could not parse loudnorm output for '$FILENAME'. Skipping."
        echo
        FAILED=$((FAILED + 1))
        continue
    fi

    echo " -- Measured: I=$M_I  TP=$M_TP  LRA=$M_LRA  Thresh=$M_THRESH  Offset=$M_OFFSET"
    echo " -- Pass 2: Applying normalization..."

    # Pass 2: apply linear normalization, copy video stream
    "$FFMPEG" -hide_banner -i "$INPUT_FILE" \
        -af "loudnorm=I=${TARGET_I}:TP=${TARGET_TP}:LRA=${TARGET_LRA}\
:measured_I=${M_I}:measured_TP=${M_TP}:measured_LRA=${M_LRA}\
:measured_thresh=${M_THRESH}:offset=${M_OFFSET}\
:linear=true:print_format=summary" \
        -c:v copy \
        -y "$OUTPUT_FILE"

    if [[ $? -eq 0 ]]; then
        echo " -- Done: $OUTPUT_FILE"
    else
        echo " [ERROR] ffmpeg failed on pass 2 for '$FILENAME'"
        FAILED=$((FAILED + 1))
    fi

    echo
done

echo "============================================================"
echo " Finished. $DONE file(s) processed, $FAILED failed."
echo "============================================================"

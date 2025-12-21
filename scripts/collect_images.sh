#!/bin/bash
# collect_images.sh
LABEL=$1
DATE=$(date +"%Y-%m-%d")
OUTPUT_DIR="data/collected/$DATE/$LABEL"
mkdir -p "$OUTPUT_DIR"

COUNTER=1
while true; do
    FILENAME="$OUTPUT_DIR/${LABEL}_$(date +%H%M%S)_${COUNTER}.jpg"
    fswebcam -r 640x480 --no-banner "$FILENAME"
    COUNTER=$((COUNTER + 1))
sleep 2
done
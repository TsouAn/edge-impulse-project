#!/bin/bash
set -e

DATA_DIR="$1"
for label_dir in "$DATA_DIR"/*; do
    LABEL=$(basename "$label_dir")
    ./scripts/upload_data.sh "$LABEL" "$label_dir"/*.{jpg,jpeg,png,bmp}
done
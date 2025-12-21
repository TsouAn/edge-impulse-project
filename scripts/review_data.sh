#!/bin/bash
# review_data.sh -審查數據品質

label_dir=$1
for label_dir in "$DATA_DIR"/*; do
    LABEL=$(basename "$label_dir")
    COUNT=$(find "$label_dir" -type f \( -name "*.jpg" -o -name "*.png" \) | wc -l)
    SIZES=$(identify -format "%wx%h\n" "$label_dir"/*.jpg | sort | uniq -c)
    echo "標籤 :$LABEL"
    echo "圖片數量 :$COUNT"
    echo "圖片尺寸分佈 :"
    echo "$SIZES"
done

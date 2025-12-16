#!/bin/bash
# run_inference.sh - 自動化推論腳本

# 設定變數
MODEL_PATH="models/model.eim"
IMAGE_PATH="data/test/test.jpg"
SCRIPT_PATH="scripts/classify_od.py"

# 檢查檔案是否存在
if [ ! -f "$MODEL_PATH" ]; then
  echo "錯誤: 找不到模型檔案 $MODEL_PATH"
  exit 1
fi

if [ ! -f "$IMAGE_PATH" ]; then
  echo "錯誤: 找不到圖片檔案 $IMAGE_PATH"
  exit 1
fi

# 確保模型有執行權限
chmod +x "$MODEL_PATH"

# 執行推論
echo "開始推論..."
python3 "$SCRIPT_PATH" "$MODEL_PATH" "$IMAGE_PATH"
echo "推論完成!"

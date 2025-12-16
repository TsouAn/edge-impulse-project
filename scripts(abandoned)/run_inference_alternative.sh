#!/bin/bash
#run_inference.sh full ver.

set -e #stop on error

#顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#日誌函數
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

#主程式
main() {
    local MODEL_PATH="models/model.eim"
    local SCRIPT_PATH="scripts/classify_od.py"
    if [ $# -eq 0 ]; then
        log_error "使用方式: $0 <圖片路徑>"
        exit 1
    fi

    local IMAGE_PATH=$1

    #驗證邏輯
    if [ ! -f "$MODEL_PATH" ]; then
        log_error "找不到模型: $MODEL_PATH"
        exit 1
    fi

    if [ ! -f "$IMAGE_PATH" ]; then
        log_error "找不到圖片: $IMAGE_PATH"
        exit 1
    fi
    
    #生成時間戳記
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    local OUTPUT_DIR
    OUTPUT_DIR="results/${TIMESTAMP}"
    mkdir -p "$OUTPUT_DIR"

    #執行推論
    log_info "準備推論..."
    chmod +x "$MODEL_PATH"
    if python3 "$SCRIPT_PATH" "$MODEL_PATH" "$IMAGE_PATH" | tee "$OUTPUT_DIR/inference_log.txt"; then
        log_info "推論完成。"
        log_info "結果已儲存到: $OUTPUT_DIR"
        cp "$IMAGE_PATH" "$OUTPUT_DIR/" #複製測試圖片
    else
        log_error "推論失敗。"
        exit 1
    fi

    
}

main "$@"
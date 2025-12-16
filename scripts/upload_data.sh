#!/bin/bash
# 上傳數據到edge impulse
set -e
set -o pipefail

#color definition
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#log function
log_info() {
    echo -e "${GREEN}[資訊]${NC} $1"
}
log_error() {
    echo -e "${RED}[錯誤]${NC} $1" >&2
}
log_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

upload_data() {
    local CATEGORY="$1"
    local LABEL="$2"
    local FILE="$3"
    edge-impulse-uploader \
      --api-key "$EI_API_KEY" \
      --category "$CATEGORY" \
      --label "$LABEL" \
      "$FILE"
}

main() {
    local CATEGORY="training"
    local LABEL=""
    local FILE=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -c|--category)
          CATEGORY="$2"; shift 2 ;;
        -h|--help)
              echo "用法: $0 [-c training|test|split](不填則預設為training) <標籤(coffee/lamp)> <檔案路徑>"; exit 0 ;;
        --) shift; break;;
        *) break ;;
      esac
    done
    LABEL="$1"
    FILE="$2"
    
    if [ -z "$LABEL" ] || [ -z "$FILE" ]; then
        log_error "缺少必要參數。\n用法: $0 [-c training|test|split](不填則預設為training) <標籤(coffee/lamp)> <檔案路徑>"
        exit 1
    fi
    
    if [ -z "$EI_API_KEY" ]; then
        log_error "找不到API key。\n請確認是否已將其寫入環境變數，或儲存為設定檔。"
        exit 1
    fi

    case "$CATEGORY" in
      training | test | split) ;;
      *)
        log_error "資料集類別僅支援 training/test/split，但接收到: $CATEGORY"
        exit 1
        ;;
    esac

    case "$LABEL" in
      coffee | lamp) ;;
      *)
        log_error "標籤類別僅支援 coffee/lamp，但接收到: $LABEL"
        exit 1
        ;;
    esac

    if [ ! -f "$FILE" ]; then
        log_error "找不到圖片: $FILE"
        exit 1
    fi
    
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    local LOG_DIR
    LOG_DIR="logs"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/upload_${LABEL}_${TIMESTAMP}.log"

    log_info "正在準備上傳到 ${CATEGORY} ..."
    if upload_data "$CATEGORY" "$LABEL" "$FILE" 2>&1 | tee "$LOG_FILE"; then
      if grep -q "An item with this hash already exists" "$LOG_FILE"; then
        log_error "上傳失敗: 已有相同的檔案"
        log_info "日誌已儲存至: $LOG_FILE"
        exit 1
      fi
      if grep -q "Failed to upload" "$LOG_FILE"; then
        log_error "上傳失敗: 原因未知(退出碼為 0)。"
        log_info "日誌已儲存至: $LOG_FILE"
        exit 1
      fi
      log_info "上傳完成。"
    else 
      log_error "上傳失敗。原因未知(退出碼非 0)。"
    fi
    log_info "日誌已儲存至: $LOG_FILE"
}

main "$@"
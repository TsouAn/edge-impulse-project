#!/bin/bash
# upload_data.sh - 整合批次處理與自動標籤偵測功能

set -e 

# 日誌設定
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
write_log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

# 檢查 API Key
check_api_key() {
  if [ -z "$EI_API_KEY" ]; then
    log_error "請設置 EI_API_KEY 環境變數"
    exit 1
  fi
}

# 單一檔案上傳核心邏輯
upload_file() {
  local FILE=$1
  local CATEGORY=$2
  local DATASET_TYPE=$3
  
  API_URL="https://ingestion.edgeimpulse.com/api/training/files"
  if [ "$DATASET_TYPE" = "test" ]; then
    API_URL="https://ingestion.edgeimpulse.com/api/testing/files"
  fi
  
  RESPONSE=$(curl -s -X POST -H "x-api-key: $EI_API_KEY" -F "data=@$FILE" -F "label=$CATEGORY" "$API_URL")
  
  if echo "$RESPONSE" | grep -q '"success":true'; then
    log_success "✓ $FILE 上傳成功 (標籤: $CATEGORY)"
    write_log "SUCCESS - $CATEGORY: $FILE"
    return 0
  else
    log_error "✗ $FILE 上傳失敗"
    write_log "FAILED - $CATEGORY: $FILE - $RESPONSE"
    return 1
  fi
}

# 批次處理邏輯：遍歷日期目錄下的所有標籤資料夾
process_batch() {
  local TARGET_DIR=$1
  local MODE=$2

  if [ ! -d "$TARGET_DIR" ]; then
    log_error "目錄不存在: $TARGET_DIR"
    exit 1
  fi

  log_info "正在掃描批次目錄: $TARGET_DIR"
  
  # 遍歷目標目錄下的每個子資料夾
  for label_path in "$TARGET_DIR"/*/; do
    # 取得資料夾名稱作為標籤 (如: coffee, lamp)
    LABEL=$(basename "$label_path")
    
    # 搜尋該標籤下的所有圖片
    shopt -s nullglob
    FILES=("$label_path"*.{jpg,jpeg,png})
    
    if [ ${#FILES[@]} -eq 0 ]; then
      continue
    fi

    log_info ">>> 開始處理標籤: $LABEL (共 ${#FILES[@]} 張圖片)"
    
    # 執行上傳與分割邏輯
    local SUCCESS=0
    if [ "$MODE" = "split" ]; then
      TRAIN_LIMIT=$(( ${#FILES[@]} * 80 / 100 ))
      for ((i=0; i<${#FILES[@]}; i++)); do
        SUB_MODE="train"; [ $i -ge $TRAIN_LIMIT ] && SUB_MODE="test"
        upload_file "${FILES[$i]}" "$LABEL" "$SUB_MODE" && ((SUCCESS++)) || true
      done
    else
      for FILE in "${FILES[@]}"; do
        upload_file "$FILE" "$LABEL" "$MODE" && ((SUCCESS++)) || true
      done
    fi
    log_info "標籤 [$LABEL] 處理完畢，成功: $SUCCESS"
  done
}

# 主程式入口
main() {
  DATASET_TYPE="train"
  BATCH_MODE=false
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      -c|--category) DATASET_TYPE="$2"; shift 2 ;;
      -b|--batch) BATCH_MODE=true; shift ;;
      *) break ;;
    esac
  done

  check_api_key
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  LOG_FILE="$LOG_DIR/batch_upload_${TIMESTAMP}.log"

  if [ "$BATCH_MODE" = true ]; then
    # 執行批次模式，傳入資料夾路徑
    process_batch "$1" "$DATASET_TYPE"
  else
    # 原有的單一上傳邏輯
    LABEL=$1; shift; FILES=("$@")
    for F in "${FILES[@]}"; do upload_file "$F" "$LABEL" "$DATASET_TYPE"; done
  fi
}

main "$@"

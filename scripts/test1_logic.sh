#!/bin/bash
# upload_data.sh - 進階版上傳腳本到 Edge Impulse
# 支援三種模式: train (訓練集)、test (測試集)、split (自動分割 80/20)
# 新增: 自動記錄上傳歷史

set -e # 遇到錯誤立即停止

# 日誌目錄設定
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

# 顏色輸出函數
log_info() {
  echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_error() {
  echo -e "\033[0;31m[ERROR]\033[0m $1"
}

log_warning() {
  echo -e "\033[0;33m[WARNING]\033[0m $1"
}

log_success() {
  echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

# 寫入日誌文件
write_log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 顯示使用說明
show_usage() {
  echo "使用方法: $0 [OPTIONS] <category> <files...>"
  echo ""
  echo "選項:"
  echo "  -c, --category <train|test|split>  指定數據集類型 (預設: train)"
  echo "  -h, --help                         顯示此幫助信息"
  echo ""
  echo "範例:"
  echo "  基本上傳 (訓練集):"
  echo "    $0 coffee data/upload_test/coffee*.jpg"
  echo ""
  echo "  測試集上傳:"
  echo "    $0 --category test lamp data/upload_test/lamp1.jpg"
  echo ""
  echo "  自動分割 (80/20):"
  echo "    $0 -c split coffee data/upload_test/coffee*.jpg"
  echo ""
  echo "日誌文件保存在 logs/ 目錄下，格式: upload_{標籤}_{時間戳記}.log"
  exit 0
}

# 檢查 API Key
check_api_key() {
  if [ -z "$EI_API_KEY" ]; then
    log_error "請設置 EI_API_KEY 環境變量"
    echo "使用方法: 編輯bash設定檔 nano ~/.bashrc # 在檔案最後加入 export EI_API_KEY=\"ei_你的金鑰\""
    exit 1
  fi
}

# 上傳單個文件
upload_file() {
  local FILE=$1
  local CATEGORY=$2
  local DATASET_TYPE=$3
  
  if [ ! -f "$FILE" ]; then
    log_warning "跳過: $FILE (文件不存在)"
    write_log "SKIP - 文件不存在: $FILE"
    return 1
  fi
  
  # 構建 API URL
  if [ "$DATASET_TYPE" = "test" ]; then
    API_URL="https://ingestion.edgeimpulse.com/api/testing/files"
  else
    API_URL="https://ingestion.edgeimpulse.com/api/training/files"
  fi
  
  log_info "上傳: $FILE → [$DATASET_TYPE] $CATEGORY"
  
  # 使用 Edge Impulse API 上傳
  RESPONSE=$(curl -s -X POST \
    -H "x-api-key: $EI_API_KEY" \
    -F "data=@$FILE" \
    -F "label=$CATEGORY" \
    "$API_URL")
  
  # 檢查是否成功
  if echo "$RESPONSE" | grep -q '"success":true'; then
    log_success "✓ $FILE"
    write_log "SUCCESS - 類別: $CATEGORY, 類型: $DATASET_TYPE, 文件: $FILE"
    return 0
  else
    log_error "✗ $FILE"
    log_error "回應: $RESPONSE"
    write_log "FAILED - 類別: $CATEGORY, 類型: $DATASET_TYPE, 文件: $FILE, 錯誤: $RESPONSE"
    return 1
  fi
}

# 主程序
main() {
  # 預設參數
  DATASET_TYPE="train"
  
  # 解析參數
  while [[ $# -gt 0 ]]; do
    case $1 in
      -c|--category)
        DATASET_TYPE="$2"
        shift 2
        ;;
      -h|--help)
        show_usage
        ;;
      -*)
        log_error "未知選項: $1"
        show_usage
        ;;
      *)
        break
        ;;
    esac
  done
  
  # 檢查必需參數
  if [ $# -lt 2 ]; then
    log_error "參數不足"
    show_usage
  fi
  
  CATEGORY=$1
  shift
  FILES=("$@")
  
  # 驗證數據集類型
  if [[ ! "$DATASET_TYPE" =~ ^(train|test|split)$ ]]; then
    log_error "無效的數據集類型: $DATASET_TYPE"
    log_error "只支援: train, test, split"
    exit 1
  fi
  
  # 檢查 API Key
  check_api_key
  
  # 建立日誌文件
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  LOG_FILE="$LOG_DIR/upload_${CATEGORY}_${TIMESTAMP}.log"
  
  # 顯示配置信息
  echo "======================================"
  log_info "Edge Impulse 數據上傳工具 - 進階版"
  echo "======================================"
  log_info "類別: $CATEGORY"
  log_info "模式: $DATASET_TYPE"
  log_info "文件數量: ${#FILES[@]}"
  log_info "日誌文件: $LOG_FILE"
  echo "======================================"
  
  # 寫入日誌標題
  write_log "=========================================="
  write_log "Edge Impulse 上傳記錄"
  write_log "=========================================="
  write_log "類別: $CATEGORY"
  write_log "模式: $DATASET_TYPE"
  write_log "文件總數: ${#FILES[@]}"
  write_log "=========================================="
  
  # 處理 split 模式
  if [ "$DATASET_TYPE" = "split" ]; then
    log_info "使用自動分割模式 (80% 訓練 / 20% 測試)"
    
    # 計算分割點
    TOTAL=${#FILES[@]}
    TRAIN_COUNT=$((TOTAL * 80 / 100))
    
    log_info "訓練集: $TRAIN_COUNT 個文件"
    log_info "測試集: $((TOTAL - TRAIN_COUNT)) 個文件"
    
    write_log "分割模式: 訓練集 $TRAIN_COUNT 個 / 測試集 $((TOTAL - TRAIN_COUNT)) 個"
    
    SUCCESS_COUNT=0
    FAIL_COUNT=0
    
    # 上傳訓練集
    log_info "開始上傳訓練集..."
    write_log "--- 開始上傳訓練集 ---"
    for ((i=0; i<TRAIN_COUNT; i++)); do
      if upload_file "${FILES[$i]}" "$CATEGORY" "train"; then
        ((SUCCESS_COUNT++))
      else
        ((FAIL_COUNT++))
      fi
    done
    
    # 上傳測試集
    log_info "開始上傳測試集..."
    write_log "--- 開始上傳測試集 ---"
    for ((i=TRAIN_COUNT; i<TOTAL; i++)); do
      if upload_file "${FILES[$i]}" "$CATEGORY" "test"; then
        ((SUCCESS_COUNT++))
      else
        ((FAIL_COUNT++))
      fi
    done
  else
    # 單一模式上傳
    SUCCESS_COUNT=0
    FAIL_COUNT=0
    
    write_log "--- 開始上傳 ($DATASET_TYPE) ---"
    for FILE in "${FILES[@]}"; do
      if upload_file "$FILE" "$CATEGORY" "$DATASET_TYPE"; then
        ((SUCCESS_COUNT++))
      else
        ((FAIL_COUNT++))
      fi
    done
  fi
  
  # 寫入統計結果到日誌
  write_log "=========================================="
  write_log "上傳完成統計"
  write_log "成功: $SUCCESS_COUNT 個文件"
  write_log "失敗: $FAIL_COUNT 個文件"
  write_log "=========================================="
  
  # 顯示統計結果
  echo "======================================"
  log_info "上傳完成!"
  log_success "成功: $SUCCESS_COUNT 個文件"
  if [ $FAIL_COUNT -gt 0 ]; then
    log_error "失敗: $FAIL_COUNT 個文件"
  fi
  log_info "詳細記錄已保存到: $LOG_FILE"
  echo "======================================"
  
  # 返回錯誤碼
  if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
  fi
}

# 執行主程序
main "$@"



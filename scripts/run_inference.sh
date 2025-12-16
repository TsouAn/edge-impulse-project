#!/bin/bash
# run_inference.sh - 全面修正版 (批量與單張模式皆支援 Log)

# ==========================================
# 全域配置
# ==========================================
set -e 

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' 

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# ==========================================
# 主程式
# ==========================================
main() {
  local MODEL_PATH="models/model.eim"
  local SCRIPT_PATH="scripts/test2_od.py"

  # 1. 準備輸出目錄 (無論單張或批量都先建立)
  # ------------------------------------------
  local TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  local OUTPUT_DIR="results/${TIMESTAMP}"
  mkdir -p "$OUTPUT_DIR"
  
  echo "-------------------------------------"
  log_info "結果將儲存於: $OUTPUT_DIR"
  echo "-------------------------------------"

  # 2. 檢查自訂模型參數 (第二個參數)
  if [ -n "$2" ]; then
    MODEL_PATH="$2"
    log_info "使用自訂模型: $MODEL_PATH"
  fi

  if [ ! -f "$MODEL_PATH" ]; then
    log_error "找不到模型檔案 $MODEL_PATH"
    return 1
  fi
  chmod +x "$MODEL_PATH"

  # 3. 執行推論 (同時記錄 Log 到螢幕與檔案)
  # ------------------------------------------
  # 使用 { ... } 2>&1 | tee ... 將整段邏輯的輸出都抓下來
  {
      if [ -z "$1" ]; then
        # === 情況 A: 批量測試 ===
        log_info "模式: 批量測試 (讀取 images/test/*.jpg)"
        python3 -u "$SCRIPT_PATH" "$MODEL_PATH"
        
        # 批量模式後，嘗試將結果圖片搬移到當次的時間戳記資料夾，保持整潔
        # (因為 Python 腳本預設是存在 results/ 根目錄)
        log_info "正在整理結果圖片..."
        mv results/result_*.jpg "$OUTPUT_DIR/" 2>/dev/null || true

      else
        # === 情況 B: 單張測試 ===
        local IMAGE_PATH="$1"
        if [ ! -f "$IMAGE_PATH" ]; then
          log_error "找不到圖片 $IMAGE_PATH"
          return 1
        fi
        
        log_info "模式: 單張測試"
        log_info "圖片: $IMAGE_PATH"
        
        python3 -u "$SCRIPT_PATH" "$MODEL_PATH" "$IMAGE_PATH"
        
        # 搬移該張結果圖
        local BASE_NAME=$(basename "$IMAGE_PATH")
        mv "results/result_${BASE_NAME}" "$OUTPUT_DIR/" 2>/dev/null || true
        
        # 備份原始圖片
        cp "$IMAGE_PATH" "$OUTPUT_DIR/"
      fi
      
  } 2>&1 | tee "$OUTPUT_DIR/inference_log.txt"
  
  # ------------------------------------------
  log_info "執行完成！"
  log_info "請查看完整紀錄: $OUTPUT_DIR/inference_log.txt"
}

main "$@"

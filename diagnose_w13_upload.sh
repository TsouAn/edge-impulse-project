#!/bin/bash
# diagnose_w13_upload.sh - W13 上傳問題自動診斷

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════╗"
echo "║  W13 上傳問題診斷（edge-impulse-uploader）║"
echo "╚═══════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

ISSUES=0

# 檢查 1: API Key 設定
echo -e "${YELLOW}[檢查 1/5] API Key 環境變數${NC}"
if [ -z "$EI_API_KEY" ]; then
    echo -e "  ${RED}✗ EI_API_KEY 未設定${NC}"
    echo ""
    echo "  解決方法："
    echo "    export EI_API_KEY='your_api_key_here'"
    echo ""
    ISSUES=$((ISSUES + 1))
else
    echo -e "  ${GREEN}✓ EI_API_KEY 已設定${NC}"
    echo "    前 20 字元: ${EI_API_KEY:0:20}..."
    
    # 檢查格式
    if [[ $EI_API_KEY == ei_* ]]; then
        echo -e "  ${GREEN}✓ 格式正確（以 ei_ 開頭）${NC}"
    else
        echo -e "  ${YELLOW}⚠ 格式可能錯誤（應以 ei_ 開頭）${NC}"
        ISSUES=$((ISSUES + 1))
    fi
fi

echo ""

# 檢查 2: 驗證 API Key
if [ -n "$EI_API_KEY" ]; then
    echo -e "${YELLOW}[檢查 2/5] 驗證 API Key 有效性${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        "https://studio.edgeimpulse.com/v1/api/auth/projects" \
        -H "x-api-key: $EI_API_KEY")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | head -n -1)
    
    if [ "$HTTP_CODE" = "200" ]; then
        SUCCESS=$(echo "$BODY" | jq -r '.success' 2>/dev/null)
        
        if [ "$SUCCESS" = "true" ]; then
            echo -e "  ${GREEN}✓ API Key 有效${NC}"
        else
            echo -e "  ${RED}✗ API Key 無效${NC}"
            echo "    回應: $BODY"
            ISSUES=$((ISSUES + 1))
        fi
    else
        echo -e "  ${RED}✗ API 請求失敗 (HTTP $HTTP_CODE)${NC}"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo -e "${YELLOW}[檢查 2/5] 跳過（API Key 未設定）${NC}"
fi

echo ""

# 檢查 3: 檢查專案數量
if [ -n "$EI_API_KEY" ] && [ "$HTTP_CODE" = "200" ]; then
    echo -e "${YELLOW}[檢查 3/5] 檢查關聯的專案${NC}"
    
    PROJECT_COUNT=$(echo "$BODY" | jq '.projects | length' 2>/dev/null)
    
    if [ -z "$PROJECT_COUNT" ] || [ "$PROJECT_COUNT" = "null" ]; then
        echo -e "  ${RED}✗ 無法解析專案列表${NC}"
        ISSUES=$((ISSUES + 1))
    elif [ "$PROJECT_COUNT" -eq 0 ]; then
        echo -e "  ${RED}✗ 此 API Key 沒有關聯任何專案${NC}"
        echo ""
        echo "  這是最常見的 404 原因！"
        echo ""
        echo "  解決方法："
        echo "    1. 前往 https://studio.edgeimpulse.com/"
        echo "    2. 開啟你的專案（或建立新專案）"
        echo "    3. 點選 Keys 頁面"
        echo "    4. 在專案內產生新的 API Key"
        echo "    5. 重新設定: export EI_API_KEY='新的key'"
        echo ""
        ISSUES=$((ISSUES + 1))
    elif [ "$PROJECT_COUNT" -eq 1 ]; then
        echo -e "  ${GREEN}✓ API Key 關聯到 1 個專案（正常）${NC}"
        
        PROJECT_ID=$(echo "$BODY" | jq -r '.projects[0].id' 2>/dev/null)
        PROJECT_NAME=$(echo "$BODY" | jq -r '.projects[0].name' 2>/dev/null)
        echo ""
        echo "  專案資訊："
        echo "    ID: $PROJECT_ID"
        echo "    名稱: $PROJECT_NAME"
        echo "    URL: https://studio.edgeimpulse.com/studio/$PROJECT_ID"
    else
        echo -e "  ${YELLOW}⚠ API Key 關聯到 $PROJECT_COUNT 個專案${NC}"
        echo ""
        echo "  你的專案列表："
        echo "$BODY" | jq -r '.projects[] | "    [\(.id)] \(.name)"' 2>/dev/null
        echo ""
        echo "  建議："
        echo "    在上傳時加上 --project-id 參數指定專案"
        echo "    或使用專案專屬的 API Key"
    fi
else
    echo -e "${YELLOW}[檢查 3/5] 跳過（API Key 驗證失敗）${NC}"
fi

echo ""

# 檢查 4: edge-impulse-uploader 安裝
echo -e "${YELLOW}[檢查 4/5] edge-impulse-uploader 工具${NC}"

if command -v edge-impulse-uploader &> /dev/null; then
    VERSION=$(edge-impulse-uploader --version 2>&1 | head -1)
    echo -e "  ${GREEN}✓ 已安裝${NC}"
    echo "    版本: $VERSION"
    
    # 檢查是否為舊版本
    VERSION_NUM=$(echo "$VERSION" | grep -oP '\d+\.\d+\.\d+' | head -1)
    if [ -n "$VERSION_NUM" ]; then
        MAJOR=$(echo "$VERSION_NUM" | cut -d. -f1)
        MINOR=$(echo "$VERSION_NUM" | cut -d. -f2)
        
        if [ "$MAJOR" -lt 1 ] || ([ "$MAJOR" -eq 1 ] && [ "$MINOR" -lt 18 ]); then
            echo -e "  ${YELLOW}⚠ 版本較舊，建議更新${NC}"
            echo "    執行: sudo npm update -g edge-impulse-cli"
        fi
    fi
else
    echo -e "  ${RED}✗ 未安裝${NC}"
    echo ""
    echo "  安裝方法："
    echo "    sudo npm install -g edge-impulse-cli"
    echo ""
    ISSUES=$((ISSUES + 1))
fi

echo ""

# 檢查 5: 網路連線
echo -e "${YELLOW}[檢查 5/5] 網路連線${NC}"

# 檢查 Studio
if curl -s -I https://studio.edgeimpulse.com/ > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ 可以連接到 studio.edgeimpulse.com${NC}"
else
    echo -e "  ${RED}✗ 無法連接到 studio.edgeimpulse.com${NC}"
    ISSUES=$((ISSUES + 1))
fi

# 檢查 Ingestion API
if curl -s -I https://ingestion.edgeimpulse.com/ > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ 可以連接到 ingestion.edgeimpulse.com${NC}"
else
    echo -e "  ${RED}✗ 無法連接到 ingestion.edgeimpulse.com${NC}"
    echo "    這個端點用於上傳數據"
    ISSUES=$((ISSUES + 1))
fi

echo ""
echo "═══════════════════════════════════════════"

# 總結
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ 所有檢查通過！${NC}"
    echo ""
    echo "環境設定正確，應該可以正常上傳。"
    echo ""
    echo "如果仍有問題，請嘗試："
    echo "  1. 更新 CLI 工具: sudo npm update -g edge-impulse-cli"
    echo "  2. 執行上傳時加上 --verbose 查看詳細錯誤"
    echo "  3. 檢查圖片檔案格式和大小"
else
    echo -e "${RED}✗ 發現 $ISSUES 個問題${NC}"
    echo ""
    echo "請先修正上述問題，然後再次執行此診斷腳本。"
fi

echo "═══════════════════════════════════════════"

# 顯示測試上傳指令
if [ $ISSUES -eq 0 ] && [ -n "$EI_API_KEY" ]; then
    echo ""
    echo -e "${BLUE}測試上傳指令：${NC}"
    echo ""
    echo "  # 下載測試圖片"
    echo "  wget https://picsum.photos/320/320 -O test.jpg"
    echo ""
    echo "  # 執行上傳"
    echo "  edge-impulse-uploader \\"
    echo "    --api-key \"\$EI_API_KEY\" \\"
    echo "    --category train \\"
    echo "    --label test \\"
    echo "    --verbose \\"
    echo "    test.jpg"
    echo ""
fi

exit $ISSUES

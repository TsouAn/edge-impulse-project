# Edge  Impulse Linux Object Detection(物件偵測系統)

## 1.專案簡介

我們利用Python 與 Edge Impulse 技術，讓我們利用他們的技術遷移學習
專案使用虛擬機linux裝置連接，載入已經完成clone訓練好的模型(`model.eim`)，即時標記出畫面中的物體並顯示其信心指數 (Confidence Score)。

**主要功能**
**推論** 使用linux x86編譯過的 `.eim`模型。

## 2.團隊成員

| 姓名 | 負責項目 | 分工細節 |
| :--- | :--- | :---|
| **鄒鈞安** | 核心開發 | 負責模型訓練 、 python腳本整合|

## 3.環境需求(Environment Requirements)
請確保你的linux 裝置已安裝以下環境:

**作業程式**:Linux OS（推薦 Ubuntu 20.04 或更新版本）
**處理器架構**:x86_64（Intel/AMD）或 ARM64 架構處理器
**程式語言**:Python 3.7 或更新版本，支援 pip 套件管理
**Node.js 執行環境**:Node.js 18+ LTS 版本（重要：避免使用 v24+）

**必要套件**:
`edge-impulse-linux`(核心工具，用於下載模型、執行推論與管理專案) 
`opecv-python`(影像處理)

## 4. 使用方法(Usage)

### 步驟 1:安裝套件
開啟Terminal(終端機)  執行以下指令來安裝 Edge-impulse



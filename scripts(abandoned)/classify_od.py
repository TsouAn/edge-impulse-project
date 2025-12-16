#!/usr/bin/env python3
import sys
import glob
import cv2
import numpy as np
from edge_impulse_linux.runner import ImpulseRunner

def preprocess(img_path, width, height):
    # 1. 讀取圖片
    img = cv2.imread(img_path)

    # 2. 調整大小 (Resize)
    # 為了避免形狀錯誤，建議先縮放再轉灰階，或者先轉灰階再縮放皆可
    # 這裡使用簡單縮放至模型需求的寬高
    img_resized = cv2.resize(img, (width, height))
    img_rgb = cv2.cvtColor(img_resized, cv2.COLOR_BGR2RGB)
    # 3. 轉為灰階 (Grayscale) - 這是必要的！
    # 因為模型輸入是 320x320x1 (102400 features)
    img_gray = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2GRAY)
    # 4. 轉為浮點數
    img_float = img_gray.astype('float32')
    
    # 5. 處理數值範圍
    # 根據之前的測試，您的模型似乎是 Quantized (int8)，預期數值為 0~255
    # 如果偵測不到，可以嘗試取消下一行的註解變成除以 255.0
    img_processed = img_float.flatten() 
    
    return img_processed
    
def main():
    if len(sys.argv) != 2:
        print("使用方式: python3 classify_od.py <model.eim>")
        sys.exit(1)

    model_path = sys.argv[1]
    print(f"載入模型: {model_path}")
    
    runner = ImpulseRunner(model_path)
    try:
        model_info = runner.init()
        print(f"模型標籤: {model_info['model_parameters']['labels']}")
        width = model_info['model_parameters']['image_input_width']
        height = model_info['model_parameters']['image_input_height']
        
        # 尋找圖片
        image_files = glob.glob("images/*.jpg")

        for img_path in image_files:
            print(f"\n處理: {img_path}")
            
            features = preprocess(img_path, width, height)

            # --- 修正 3：直接放入特徵，不要再 preprocess 一次 ---
            try:
               result = runner.classify(features)
            except Exception as e:
                print(f"推論發生錯誤: {e}")
                continue
            
        
            # print("\n=== 原始回傳資料 ===")
            # print(result)

            # --- 這裡完全保留您原本的寫法 ---
            #if 'bounding_boxes' in result['result']:
               # for i, box in enumerate(result['result']['bounding_boxes']):
                   # print(f"物件 {i+1}: {box['label']} "
                       # f"({box['value']:.2f})")
            # -------------------------------
            # 顯示結果
            found = False
            if 'bounding_boxes' in result['result']:
                for box in result['result']['bounding_boxes']:
                    # 只要有任何分數都印出來，不設門檻，方便除錯
                    print(f"  -> 偵測到: {box['label']} (信心度: {box['value']:.2f})")
                    found = True
            
            if not found:
                print("  -> 未偵測到任何物件 (信心度過低)")
                # 如果還是沒東西，這裡會顯示模型到底回傳了什麼空的資料
                # print("  (原始回傳):", result['result'])
            

    finally:
        runner.stop()

if __name__ == "__main__":
    main()

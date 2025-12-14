#!/usr/bin/env python3
import sys
import glob
import cv2
import numpy as np
import os 
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
    
    return img_processed, img_resized
    
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
            
            features, img = preprocess(img_path, width, height)

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
            # 合併後的寫法
            if 'bounding_boxes' in result['result']:
                for i, box in enumerate(result['result']['bounding_boxes']):
                    # 1. 取出數據
                    label = box['label']
                    score = box['value']
                    x, y, w, h = box['x'], box['y'], box['width'], box['height']

                    # 2. 做第一件事：印出文字 (給你看)
                    print(f"物件 {i+1}: {label} ({score:.2f})")

                    # 3. 做第二件事：畫圖 (存檔用)
                    cv2.rectangle(img, (x, y), (x+w, y+h), (0, 255, 0), 2)
                    cv2.putText(img, label, (x, y-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
                # 最後統一存檔
                
                
                # --- 這就是您要新增的部分 (取代原本的 result.jpg) ---
                # 1. 取得原本的檔名 (例如 images1.jpg)
                filename = os.path.basename(img_path)
                
                # 2. 加上前綴 "result_" 並存檔 (變成 result_images1.jpg)
                save_name = f"result_{filename}"
                cv2.imwrite(save_name, img)
                print(f"結果已儲存: {save_name}")
            

    finally:
        runner.stop()

if __name__ == "__main__":
    main()

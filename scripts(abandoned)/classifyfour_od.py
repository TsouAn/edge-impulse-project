#!/usr/bin/env python3
import sys
import glob
import cv2
import numpy as np
import os
import time  # 新增：用於計算時間
from edge_impulse_linux.runner import ImpulseRunner

def preprocess(img_path, width, height):
    # 1. 讀取圖片
    img = cv2.imread(img_path)

    # 2. 調整大小 (Resize)
    img_resized = cv2.resize(img, (width, height))
    img_rgb = cv2.cvtColor(img_resized, cv2.COLOR_BGR2RGB)
    
    # 3. 轉為灰階 (Grayscale)
    img_gray = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2GRAY)
    
    # 4. 轉為浮點數
    img_float = img_gray.astype('float32')
    
    # 5. 展平
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
            # --- 介面調整：顯示載入的圖片名稱 ---
            print(f"載入圖片: {os.path.basename(img_path)}")
            start_time = time.time()
            features, img = preprocess(img_path, width, height)

            try:
                # --- 新增：計時開始 ---
                
                result = runner.classify(features)
                
                # --- 新增：計時結束 ---
                end_time = time.time()
                inference_time_ms = (end_time - start_time) * 1000
                
            except Exception as e:
                print(f"推論發生錯誤: {e}")
                continue
            
            # --- 介面調整：依照截圖格式輸出 ---
            if 'bounding_boxes' in result['result']:
                boxes = result['result']['bounding_boxes']
                
                print("\n=== 推論結果 ===")
                print(f"偵測到 {len(boxes)} 個物件:\n")

                for i, box in enumerate(boxes):
                    # 1. 取出數據
                    label = box['label']
                    score = box['value']
                    x, y, w, h = box['x'], box['y'], box['width'], box['height']

                    # 2. 印出文字 (依照截圖風格)
                    print(f"物件 {i+1}: {label} ({score:.2f})")
                    print(f"  位置: x={x}, y={y}, w={w}, h={h}") # 加上縮排

                    # 3. 畫圖 (存檔用)
                    cv2.rectangle(img, (x, y), (x+w, y+h), (0, 255, 0), 2)
                    cv2.putText(img, label, (x, y-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
                
                # --- 新增：顯示推論時間 ---
                print(f"\n推論時間: {int(inference_time_ms)} ms")
                print("-" * 30) # 分隔線

                # 4. 存檔
                filename = os.path.basename(img_path)
                save_name = f"result_{filename}"
                cv2.imwrite(save_name, img)
                # print(f"結果已儲存: {save_name}\n") # 如果不想讓畫面太亂，這行可以註解掉或保留
    
    finally:
        runner.stop()

if __name__ == "__main__":
    main()

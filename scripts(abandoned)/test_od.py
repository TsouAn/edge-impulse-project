#!/usr/bin/env python3
import sys
import glob
import cv2
import numpy as np
import os
import time
from edge_impulse_linux.runner import ImpulseRunner

def preprocess(img_path, width, height):
    img = cv2.imread(img_path)
    img_resized = cv2.resize(img, (width, height))
    img_rgb = cv2.cvtColor(img_resized, cv2.COLOR_BGR2RGB)
    img_gray = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2GRAY)
    img_float = img_gray.astype('float32')
    img_processed = img_float.flatten()
    return img_processed, img_resized
    
def main():
    # --- 回復成使用 sys.argv ---
    if len(sys.argv) != 2:
        print("使用方式: python3 scripts/test_od.py <models/model.eim>")
        sys.exit(1)

    model_path = sys.argv[1]
    print(f"載入模型: {model_path}")
    
    # 檢查 results 資料夾 (保留功能)
    if not os.path.exists("results"):
        os.makedirs("results")
    
    runner = ImpulseRunner(model_path)
    try:
        model_info = runner.init()
        print(f"模型標籤: {model_info['model_parameters']['labels']}")
        width = model_info['model_parameters']['image_input_width']
        height = model_info['model_parameters']['image_input_height']
        
        # 讀取 images/test/*.jpg (保留功能)
        image_files = glob.glob("images/test/*.jpg")

        if not image_files:
            print("找不到圖片，請確認 images/test 資料夾內是否有 .jpg 檔案")

        for img_path in image_files:
            print(f"載入圖片: {os.path.basename(img_path)}")
            process_start = time.time()
            features, img = preprocess(img_path, width, height)
            process_time = (time.time() - process_start) * 1000
            
            
            try:
                start_time = time.time()
                result = runner.classify(features)
                end_time = time.time()
                
                inference_time_ms = (end_time - start_time) * 1000
                
            except Exception as e:
                print(f"推論發生錯誤: {e}")
                continue
            
            if 'bounding_boxes' in result['result']:
                boxes = result['result']['bounding_boxes']
                
                print("\n=== 推論結果 ===")
                print(f"偵測到 {len(boxes)} 個物件:\n")

                for i, box in enumerate(boxes):
                    label = box['label']
                    score = box['value']
                    x, y, w, h = box['x'], box['y'], box['width'], box['height']

                    print(f"物件 {i+1}: {label} ({score:.2f})")
                    print(f"  位置: x={x}, y={y}, w={w}, h={h}")

                    cv2.rectangle(img, (x, y), (x+w, y+h), (0, 255, 0), 2)
                    cv2.putText(img, label, (x, y-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
                
                print(f"\n推論時間: {int(inference_time_ms)} ms")
                print("-" * 30)

                # 存檔到 results (保留功能)
                filename = os.path.basename(img_path)
                save_name = os.path.join("results", f"result_{filename}")
                cv2.imwrite(save_name, img)
                print(f"結果已儲存: {save_name}\n")
    
    finally:
        runner.stop()

if __name__ == "__main__":
    main()

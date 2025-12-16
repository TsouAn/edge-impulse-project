#!/usr/bin/env python3
import sys
import cv2
import numpy as np
from edge_impulse_linux.runner import ImpulseRunner

def main():
    if len(sys.argv) != 3:
        print("使用方式: python3 classify_od.py <model.eim路徑> <圖片路徑>")
        sys.exit(1)
    
    model_path = sys.argv[1]
    image_path = sys.argv[2]
    
    print(f"載入模型: {model_path}")
    print(f"載入圖片: {image_path}")
    
    # 初始化推論引擎
    runner = ImpulseRunner(model_path)
    
    try:
        model_info = runner.init()
        print(f"模型資訊:")
        print(f"  - 輸入寬度: {model_info['model_parameters']['image_input_width']}")
        print(f"  - 輸入高度: {model_info['model_parameters']['image_input_height']}")
        print(f"  - 標籤: {model_info['model_parameters']['labels']}")
        
        # 取得模型需要的尺寸
        target_width = model_info['model_parameters']['image_input_width']
        target_height = model_info['model_parameters']['image_input_height']
        
        # === 手動前處理圖片 ===
        # 1. 讀取圖片
        img = cv2.imread(image_path)
        if img is None:
            print(f"錯誤: 無法讀取圖片 {image_path}")
            sys.exit(1)
        
        print(f"原始圖片尺寸: {img.shape}")
        
        # 2. BGR -> RGB
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        
        # 3. RGB -> Grayscale (模型實際需要灰階)
        img_gray = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2GRAY)
        
        # 4. 縮放到目標尺寸
        img_resized = cv2.resize(img_gray, (target_width, target_height))
        
        # 5. 轉換為 float32
        img_float = img_resized.astype('float32')
        
        # 6. 【關鍵修正】展平成一維陣列
        img_processed = img_float.flatten()
        
        print(f"處理後圖片形狀: {img_processed.shape}, dtype: {img_processed.dtype}")
        
        # === 執行推論 ===
        print("\n開始推論...")
        result = runner.classify(img_processed)
        
        # === 顯示結果 ===
        print("\n=== 推論結果 ===")
        
        if 'bounding_boxes' in result['result']:
            boxes = result['result']['bounding_boxes']
            print(f"偵測到 {len(boxes)} 個物件:")
            for i, box in enumerate(boxes):
                print(f"\n物件 {i+1}:")
                print(f"  標籤: {box['label']}")
                print(f"  信心度: {box['value']:.2f}")
                print(f"  位置: x={box['x']}, y={box['y']}, w={box['width']}, h={box['height']}")
        else:
            print("沒有偵測到物件")
        
        print(f"\n推論時間: {result['timing']['dsp'] + result['timing']['classification']} ms")
        
    finally:
        runner.stop()

if __name__ == "__main__":
    main()
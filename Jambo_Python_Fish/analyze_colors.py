import cv2
import numpy as np
import os

# Sample images from each folder
folders = ['bobbers/full', 'bobbers/finred', 'bobbers/false']

for folder in folders:
    if not os.path.exists(folder):
        continue
    
    print(f"\n{'='*60}")
    print(f"Analyzing: {folder}")
    print('='*60)
    
    files = sorted([f for f in os.listdir(folder) if f.endswith('.png')])[:5]
    
    for fname in files:
        path = os.path.join(folder, fname)
        img = cv2.imread(path)
        if img is None:
            continue
        
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        
        # Get non-background pixels
        mask = (hsv[:,:,2] > 30) & (hsv[:,:,1] > 20)
        
        if np.sum(mask) > 0:
            h = hsv[:,:,0][mask]
            s = hsv[:,:,1][mask]
            v = hsv[:,:,2][mask]
            
            print(f"\n{fname}:")
            print(f"  Hue:        min={int(np.min(h)):3d} max={int(np.max(h)):3d} mean={np.mean(h):5.1f}")
            print(f"  Saturation: min={int(np.min(s)):3d} max={int(np.max(s)):3d} mean={np.mean(s):5.1f}")
            print(f"  Value:      min={int(np.min(v)):3d} max={int(np.max(v)):3d} mean={np.mean(v):5.1f}")

"""Analyze actual HSV color values from bobber screenshots."""
import cv2
import numpy as np
from pathlib import Path

# Approximate bobber location from screenshots (center of bobber)
# First image: bobber around x=645, y=165 (visible with red fin)
# Second image: bobber around x=645, y=170

bobber_samples = [
    ("Screenshot 1", 645, 165),
    ("Screenshot 2", 645, 170),
]

print("=" * 70)
print("BOBBER COLOR ANALYSIS")
print("=" * 70)

# Check if we have the screenshots saved
screenshots_dir = Path("bobbers/full")
if screenshots_dir.exists():
    screenshots = sorted(screenshots_dir.glob("*.png"))
    print(f"\nFound {len(screenshots)} screenshots in {screenshots_dir}")
    
    for img_path in screenshots[:5]:  # Analyze first 5
        print(f"\n{'=' * 70}")
        print(f"Analyzing: {img_path.name}")
        print('=' * 70)
        
        img = cv2.imread(str(img_path))
        if img is None:
            print(f"Failed to load {img_path}")
            continue
            
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        h, w = hsv.shape[:2]
        
        # Sample regions around expected bobber location (adjust based on image size)
        # Assuming bobber is roughly in upper-middle area
        regions = [
            ("Center-top", w//2, h//3, 20),  # Center upper third
            ("Left-center", w//3, h//2, 20),
            ("Right-center", 2*w//3, h//2, 20),
        ]
        
        for name, cx, cy, radius in regions:
            x1, y1 = max(0, cx-radius), max(0, cy-radius)
            x2, y2 = min(w, cx+radius), min(h, cy+radius)
            region = hsv[y1:y2, x1:x2]
            
            # Get color statistics
            h_vals = region[:,:,0].flatten()
            s_vals = region[:,:,1].flatten()
            v_vals = region[:,:,2].flatten()
            
            print(f"\n{name} region ({cx},{cy}) ±{radius}px:")
            print(f"  Hue:        min={h_vals.min():3d}  max={h_vals.max():3d}  mean={h_vals.mean():6.1f}")
            print(f"  Saturation: min={s_vals.min():3d}  max={s_vals.max():3d}  mean={s_vals.mean():6.1f}")
            print(f"  Value:      min={v_vals.min():3d}  max={v_vals.max():3d}  mean={v_vals.mean():6.1f}")
            
            # Find pixels with high saturation (likely bobber parts)
            high_sat_mask = s_vals > 100
            if high_sat_mask.any():
                high_sat_hues = h_vals[high_sat_mask]
                print(f"  High-sat pixels (>100): {high_sat_mask.sum()} pixels")
                print(f"    Hue range: {high_sat_hues.min()}-{high_sat_hues.max()}")

else:
    print(f"\nDirectory {screenshots_dir} not found")
    print("Looking for any bobber images in current directory...")
    
    for pattern in ["*.png", "*.jpg"]:
        imgs = list(Path(".").glob(pattern))
        if imgs:
            print(f"Found {len(imgs)} {pattern} files")
            break

print("\n" + "=" * 70)
print("RECOMMENDATION:")
print("=" * 70)
print("""
Based on typical WoW fishing bobbers:
- Red fin: Usually hue 0-10 (red/orange), but saturation might be 80-150, not 150+
- Blue body: Usually hue 95-105 (cyan), saturation might be 60-120, not 120+
- Cork: Bright whites/tans, value 150-255, saturation 0-60

The current settings might be TOO strict if the bobber colors aren't fully saturated
in-game (affected by lighting, water reflections, graphics settings).

Try lowering saturation thresholds:
- Red: saturation > 80 (instead of 150)
- Blue: saturation > 60 (instead of 120)
""")

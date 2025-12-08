import cv2
import numpy as np

# Load the image
img = cv2.imread('image.png')
if img is None:
    print("Image not found")
    exit()

# Convert to RGB
img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

# Find unique colors or dominant
unique, counts = np.unique(img_rgb.reshape(-1, 3), axis=0, return_counts=True)
sorted_colors = sorted(zip(unique, counts), key=lambda x: x[1], reverse=True)

print("Top 10 colors:")
for color, count in sorted_colors[:10]:
    print(f"Color: {color}, Count: {count}")

# Perhaps find red/blue areas
lower_red = np.array([150, 0, 0])
upper_red = np.array([255, 100, 100])
mask_red = cv2.inRange(img_rgb, lower_red, upper_red)
red_pixels = cv2.countNonZero(mask_red)
print(f"Red pixels: {red_pixels}")

lower_blue = np.array([0, 0, 150])
upper_blue = np.array([100, 100, 255])
mask_blue = cv2.inRange(img_rgb, lower_blue, upper_blue)
blue_pixels = cv2.countNonZero(mask_blue)
print(f"Blue pixels: {blue_pixels}")

# Show contours for red
contours, _ = cv2.findContours(mask_red, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
if contours:
    c = max(contours, key=cv2.contourArea)
    print(f"Largest red contour area: {cv2.contourArea(c)}")
    M = cv2.moments(c)
    if M["m00"] != 0:
        cx = int(M["m10"] / M["m00"])
        cy = int(M["m01"] / M["m00"])
        print(f"Center: ({cx}, {cy})")
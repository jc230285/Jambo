import tkinter as tk
from tkinter import ttk, messagebox
import cv2
import numpy as np
import mss
import time
import threading
import win32gui
import win32api
import win32con
from PIL import Image, ImageTk
import random
import os
import json
import ctypes
from ctypes import wintypes

# --- Utilities for Background Input ---
class WindowMgr:
    @staticmethod
    def get_hwnd(window_title):
        hwnd = win32gui.FindWindow(None, window_title)
        return hwnd

    @staticmethod
    def send_key(hwnd, key_char):
        if not hwnd:
            return
        vk_code = win32api.VkKeyScan(key_char) & 0xFF
        win32api.PostMessage(hwnd, win32con.WM_KEYDOWN, vk_code, 0)
        time.sleep(0.05 + random.uniform(0.01, 0.03)) 
        win32api.PostMessage(hwnd, win32con.WM_KEYUP, vk_code, 0)

    @staticmethod
    def move_mouse_smooth(target_x, target_y, duration=0.3):
        """Move mouse cursor smoothly to target screen coordinates using human-like bezier curve."""
        try:
            # Get current cursor position
            class POINT(ctypes.Structure):
                _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]
            pt = POINT()
            ctypes.windll.user32.GetCursorPos(ctypes.byref(pt))
            start_x, start_y = pt.x, pt.y
            
            # Generate bezier control points for natural movement
            steps = int(duration * 60)  # 60 steps per second
            if steps < 5:
                steps = 5
            
            # Add slight randomness to control point
            mid_x = (start_x + target_x) / 2 + random.randint(-20, 20)
            mid_y = (start_y + target_y) / 2 + random.randint(-20, 20)
            
            for i in range(steps + 1):
                t = i / steps
                # Quadratic bezier curve
                x = int((1-t)**2 * start_x + 2*(1-t)*t * mid_x + t**2 * target_x)
                y = int((1-t)**2 * start_y + 2*(1-t)*t * mid_y + t**2 * target_y)
                ctypes.windll.user32.SetCursorPos(x, y)
                time.sleep(duration / steps)
        except Exception as e:
            print(f"Mouse move error: {e}")
    
    @staticmethod
    def send_mouse_click(hwnd, x, y, button='right', move_cursor=False, screen_x=None, screen_y=None):
        """Post a mouse click to the target window at client coordinates (x,y).
        button: 'right' or 'left' (default 'right')
        move_cursor: if True, physically move cursor to screen_x, screen_y before clicking
        """
        if not hwnd:
            return
        
        # Optionally move cursor in human-like way
        if move_cursor and screen_x is not None and screen_y is not None:
            WindowMgr.move_mouse_smooth(screen_x, screen_y, duration=random.uniform(0.2, 0.4))
            time.sleep(random.uniform(0.05, 0.15))
        
        l_param = win32api.MAKELONG(x, y)
        if button == 'right':
            win32api.PostMessage(hwnd, win32con.WM_RBUTTONDOWN, win32con.MK_RBUTTON, l_param)
            time.sleep(0.08)
            win32api.PostMessage(hwnd, win32con.WM_RBUTTONUP, 0, l_param)
        else:
            win32api.PostMessage(hwnd, win32con.WM_LBUTTONDOWN, win32con.MK_LBUTTON, l_param)
            time.sleep(0.08)
            win32api.PostMessage(hwnd, win32con.WM_LBUTTONUP, 0, l_param)

# --- The Logic Thread ---
class FishingBotThread(threading.Thread):
    def __init__(self, config, update_log_callback, update_preview_callback, update_splash_callback, update_overlay_callback=None, update_timeout_callback=None):
        super().__init__()
        self.config = config
        self.update_log = update_log_callback
        self.update_preview = update_preview_callback
        self.update_splash = update_splash_callback # Callback for the GUI bar
        # Optional callbacks for overlay visualization and timeout update
        self.update_overlay = update_overlay_callback
        self.update_timeout = update_timeout_callback
        self.running = True
        
        self.hwnd = WindowMgr.get_hwnd(self.config['window_title'])
        if not self.hwnd:
            self.update_log(f"Error: Window '{self.config['window_title']}' not found!")
            self.running = False
        # Bobber history for training (list of dicts)
        self.history_file = self.config.get('history_file', 'bobber_history.json')
        self.bobber_dir = self.config.get('bobber_dir', 'bobbers')
        self.bobber_history = []
        # Ensure bobber directory exists
        try:
            os.makedirs(self.bobber_dir, exist_ok=True)
        except Exception:
            pass
        # load existing history if present
        try:
            if os.path.exists(self.history_file):
                with open(self.history_file, 'r') as hf:
                    self.bobber_history = json.load(hf)
        except Exception:
            self.bobber_history = []

    def run(self):
        self.update_log("Bot Started.")
        
        while self.running:
            try:
                # Only cast if casting is not disabled
                if not self.config.get('disable_casting', False):
                    self.update_log("Casting...")
                    WindowMgr.send_key(self.hwnd, self.config['cast_key'])
                    time.sleep(2.5)
                else:
                    self.update_log("Detect mode - looking for existing bobber...")
                    time.sleep(0.5) 

                find_result = self.find_bobber()
                bobber_loc = None
                confidence = 0.0
                if find_result is not None:
                    # find_result is (x, y, confidence)
                    bobber_loc = (find_result[0], find_result[1])
                    confidence = float(find_result[2])
                
                if not bobber_loc:
                    self.update_log("Bobber not found. Recasting...")
                    continue
                
                self.update_log(f"Bobber found at {bobber_loc}")
                # record detection into history and save cropped bobber image
                try:
                    ts = time.time()
                    idx = len(self.bobber_history)
                    img_filename = f"bobber_{idx:05d}_{int(ts)}.png"
                    entry = {
                        "ts": ts, 
                        "x": bobber_loc[0], 
                        "y": bobber_loc[1], 
                        "confidence": confidence,
                        "image": img_filename
                    }
                    self.bobber_history.append(entry)
                    
                    # Save cropped bobber image (60x60 region around detected center)
                    try:
                        crop_size = 60
                        left = int(bobber_loc[0] - crop_size // 2)
                        top = int(bobber_loc[1] - crop_size // 2)
                        monitor = {"top": top, "left": left, "width": crop_size, "height": crop_size}
                        with mss.mss() as sct:
                            crop_img = np.array(sct.grab(monitor))
                        crop_bgr = cv2.cvtColor(crop_img, cv2.COLOR_BGRA2BGR)
                        img_path = os.path.join(self.bobber_dir, img_filename)
                        cv2.imwrite(img_path, crop_bgr)
                    except Exception as e:
                        print(f"Failed to save bobber crop: {e}")
                    
                    # persist JSON
                    try:
                        with open(self.history_file, 'w') as hf:
                            json.dump(self.bobber_history, hf, indent=2)
                    except Exception:
                        pass
                except Exception:
                    pass
                
                # Show overlay with bobber location and confidence
                if self.update_overlay:
                    try:
                        self.update_overlay(bobber_loc[0], bobber_loc[1], confidence)
                    except Exception:
                        pass

                splash_detected = self.watch_bobber(bobber_loc)
                
                if splash_detected:
                    self.update_log("Splash detected! Reeling in...")
                    
                    if self.config.get('use_background_clicks', False):
                        rect = win32gui.GetWindowRect(self.hwnd)
                        rel_x = bobber_loc[0] - rect[0]
                        rel_y = bobber_loc[1] - rect[1]
                        WindowMgr.send_mouse_click(self.hwnd, rel_x, rel_y)
                    else:
                        WindowMgr.send_key(self.hwnd, self.config['interact_key'])
                    
                    time.sleep(1.0 + random.uniform(0.5, 1.0))
                else:
                    # Reel FAILED (timeout) - check if bobber still present before right-clicking
                    self.update_log("Reel timeout. Checking if bobber still present...")
                    time.sleep(0.5)
                    
                    try:
                        # Only proceed if bobber is CONFIRMED still at the location
                        still_present = self._is_bobber_still_at(bobber_loc[0], bobber_loc[1], check_radius=50)
                        
                        if still_present:
                            self.update_log("Bobber confirmed present - performing human-like right-click...")
                            rect = win32gui.GetWindowRect(self.hwnd)
                            rel_x = int(bobber_loc[0] - rect[0])
                            rel_y = int(bobber_loc[1] - rect[1])
                            # Move cursor in human-like way, then right-click
                            WindowMgr.send_mouse_click(
                                self.hwnd, rel_x, rel_y, 
                                button='right', 
                                move_cursor=True, 
                                screen_x=bobber_loc[0], 
                                screen_y=bobber_loc[1]
                            )
                            time.sleep(random.uniform(0.3, 0.6))
                        else:
                            self.update_log("Bobber NOT present - skipping right-click (safety)")
                    except Exception as e:
                        self.update_log(f"Safety check error: {e}")
                    
                    time.sleep(1.0 + random.uniform(0.3, 0.8))
                
                # Hide overlay after watching
                if self.update_overlay:
                    try:
                        self.update_overlay(None, None, 0)
                    except Exception:
                        pass
                time.sleep(random.uniform(1.0, 2.0))

            except Exception as e:
                self.update_log(f"Error: {e}")
                time.sleep(1)

    def capture_zone(self):
        with mss.mss() as sct:
            monitor = {
                "top": int(self.config['zone']['top']), 
                "left": int(self.config['zone']['left']), 
                "width": int(self.config['zone']['width']), 
                "height": int(self.config['zone']['height'])
            }
            img = np.array(sct.grab(monitor))
            return cv2.cvtColor(img, cv2.COLOR_BGRA2BGR)

    def find_bobber(self):
        img = self.capture_zone()
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        
        # Focus ONLY on vibrant red and blue - ignore white/cork for now
        # This should eliminate false positives from water reflections/sky
        
        # 1. Red fin - VERY vibrant red only
        red_lower = np.array([0, 150, 120])  # Much higher saturation requirement
        red_upper = np.array([10, 255, 255])
        red_mask = cv2.inRange(hsv, red_lower, red_upper)
        
        # 2. Blue/Teal body - vibrant cyan/blue ONLY
        # Narrower hue range, very high saturation to avoid water
        blue_lower = np.array([95, 120, 100])  # Even higher saturation
        blue_upper = np.array([105, 255, 255])  # Narrower hue range
        blue_mask = cv2.inRange(hsv, blue_lower, blue_upper)
        
        # Combine red and blue only (no cork detection)
        combined_mask = cv2.bitwise_or(red_mask, blue_mask)
        
        # Find contours on combined mask
        contours, _ = cv2.findContours(combined_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        best_bobber = None
        best_score = 0
        
        print(f"Total contours found: {len(contours)}")
        
        for cnt in contours:
            area = cv2.contourArea(cnt)
            if area < 15:  # Too small
                print(f"  Rejected: area {area:.1f} < 15")
                continue
            if area > 500:  # Too large - probably detecting water/background
                print(f"  Rejected: area {area:.1f} > 500")
                continue
            
            x, y, w, h = cv2.boundingRect(cnt)
            
            # Reject if too wide or too flat (bobber should be tallish)
            if w > 100 or h > 100:
                print(f"  Rejected: size {w}x{h} exceeds 100")
                continue
            if w > h:  # Width should not exceed height for a bobber
                print(f"  Rejected: width {w} > height {h} (not vertical)")
                continue
            
            # Calculate how many bobber components are present in this region
            roi_red = red_mask[y:y+h, x:x+w]
            roi_blue = blue_mask[y:y+h, x:x+w]
            roi_cork = cork_mask[y:y+h, x:x+w]
            
            red_pixels = np.sum(roi_red > 0)
            blue_pixels = np.sum(roi_blue > 0)
            cork_pixels = np.sum(roi_cork > 0)
            
            # Count components (reduced threshold)
            component_count = (red_pixels > 3) + (blue_pixels > 3) + (cork_pixels > 3)
            
            print(f"  Candidate: pos ({x},{y}) size {w}x{h}, area {area:.1f}, red={red_pixels} blue={blue_pixels} cork={cork_pixels}, components={component_count}")
            
            # Prefer tall, narrow shapes (bobber is vertical)
            aspect_ratio = h / float(max(w, 1))
            
            # Combined score: prioritize having components + vertical shape
            # Lower requirement - accept 1+ components instead of 2+
            if component_count < 1:
                print(f"    Rejected: no components found")
                continue
            
            score = component_count * 100 + aspect_ratio * 10 + area * 0.5
            
            if score > best_score:
                best_score = score
                best_bobber = (cnt, x, y, w, h, component_count)
        
        if best_bobber:
            cnt, x, y, w, h, components = best_bobber
            
            # Debug output
            print(f"Bobber detected at zone coords ({x},{y}) size {w}x{h}, components: {components}/3, score: {best_score:.1f}")
            
            # Draw outline around detected bobber
            cv2.drawContours(img, [cnt], -1, (0, 255, 0), 2)
            
            # Draw colored boxes for each component detected
            cv2.rectangle(img, (x, y), (x+w, y+h), (0, 255, 255), 1)
            cv2.putText(img, f"Bobber ({components}/3)", (x, y-5), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 255, 0), 1)
            
            self.update_preview(img)
            
            # Calculate screen coordinates
            screen_x = self.config['zone']['left'] + x + w//2
            screen_y = self.config['zone']['top'] + y + h//2
            confidence = min(1.0, best_score / 300.0)
            
            return (screen_x, screen_y, float(confidence))
        
        print(f"No bobber detected. Found {len(contours)} contours total.")
        self.update_preview(img)
        return None

    def watch_bobber(self, bobber_pos):
        start_time = time.time()
        monitor_size = 60
        left = int(bobber_pos[0] - monitor_size//2)
        top = int(bobber_pos[1] - monitor_size//2)
        monitor = {"top": top, "left": left, "width": monitor_size, "height": monitor_size}
        last_mean = None
        
        with mss.mss() as sct:
            while time.time() - start_time < self.config['reel_timeout']:
                if not self.running: return False
                try:
                    if self.update_timeout:
                        remaining = max(0, int(self.config['reel_timeout'] - (time.time() - start_time)))
                        try:
                            self.update_timeout(remaining)
                        except Exception:
                            pass
                except Exception:
                    pass
                try:
                    img = np.array(sct.grab(monitor))
                    gray = cv2.cvtColor(img, cv2.COLOR_BGRA2GRAY)
                    current_mean = np.mean(gray)
                    
                    if last_mean is not None:
                        diff = abs(current_mean - last_mean)
                        
                        # UPDATE GUI WITH CURRENT NOISE LEVEL
                        self.update_splash(diff)
                        # Update timeout countdown
                        if self.update_timeout:
                            remaining = max(0, int(self.config['reel_timeout'] - (time.time() - start_time)))
                            try:
                                self.update_timeout(remaining)
                            except Exception:
                                pass
                        
                        if diff > self.config['sensitivity']: 
                            return True
                    last_mean = current_mean
                    time.sleep(0.1)
                except Exception:
                    return False
        
        # Reset bar and timeout when done watching
        self.update_splash(0)
        if self.update_timeout:
            try:
                self.update_timeout(0)
            except Exception:
                pass
        return False

    def _is_bobber_still_at(self, x, y, check_radius=30):
        """Check a small region around absolute screen coords (x,y) for bobber-like color/texture.
        Returns True ONLY if bobber is confidently detected in that region.
        Uses strict saturation thresholds to avoid water false positives.
        """
        try:
            left = int(x - check_radius // 2)
            top = int(y - check_radius // 2)
            monitor = {"top": top, "left": left, "width": check_radius, "height": check_radius}
            with mss.mss() as sct:
                img = np.array(sct.grab(monitor))
            
            bgr = cv2.cvtColor(img, cv2.COLOR_BGRA2BGR)
            hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
            
            # Same strict thresholds as find_bobber
            red_lower = np.array([0, 150, 120])
            red_upper = np.array([10, 255, 255])
            red_mask = cv2.inRange(hsv, red_lower, red_upper)
            red_pixels = np.sum(red_mask > 0)
            
            blue_lower = np.array([95, 120, 100])
            blue_upper = np.array([105, 255, 255])
            blue_mask = cv2.inRange(hsv, blue_lower, blue_upper)
            blue_pixels = np.sum(blue_mask > 0)
            
            # Require at least 1 component with sufficient pixels (NO CORK)
            components_found = (red_pixels > 5) + (blue_pixels > 5)
            
            if components_found >= 1:
                return True
            
        except Exception as e:
            print(f"Bobber check error: {e}")
            return False
        
        return False

    def stop(self):
        self.running = False
        self.update_splash(0)
        if self.update_overlay:
            try:
                self.update_overlay(None, None, 0)
            except Exception:
                pass

# --- The GUI ---
class FishingApp:
    def __init__(self, root):
        self.root = root
        self.root.title("AutoFisher Pro (Visual Debug)")
        self.root.geometry("500x750")
        # Keep UI on top
        try:
            self.root.attributes('-topmost', True)
        except Exception:
            pass
        
        self.bot_thread = None
        self.config_file = "fishing_config.json"
        
        # --- Default Variables ---
        self.zone = {'top': 100, 'left': 100, 'width': 600, 'height': 400}
        self.window_title = tk.StringVar(value="World of Warcraft")
        self.cast_key = tk.StringVar(value="1")
        self.interact_key = tk.StringVar(value="9") 
        self.sensitivity = tk.DoubleVar(value=2.0)
        self.current_splash_val = tk.DoubleVar(value=0.0) # For progress bar
        self.reel_timeout = tk.IntVar(value=30)  # Reel timeout in seconds (default 30s)
        self.disable_casting = tk.BooleanVar(value=False)  # Skip casting, only detect existing bobbers
        self.template_path = "bobber_template.png"
        # Overlay window variable - lazy init
        self.overlay_win = None
        self.overlay_canvas = None
        self.overlay_rect = None
        self.overlay_text = None
        self.timeout_remaining = tk.IntVar(value=0)

        # --- Load Config if exists ---
        self.load_config()

        # --- UI Layout ---
        settings_frame = ttk.LabelFrame(root, text="Configuration")
        settings_frame.pack(fill="x", padx=10, pady=5)
        
        ttk.Label(settings_frame, text="Cast Key:").grid(row=0, column=0, padx=5, pady=5)
        ttk.Entry(settings_frame, textvariable=self.cast_key, width=5).grid(row=0, column=1, sticky="w")

        ttk.Label(settings_frame, text="Interact Key:").grid(row=1, column=0)
        ttk.Entry(settings_frame, textvariable=self.interact_key, width=5).grid(row=1, column=1, sticky="w")
        
        ttk.Label(settings_frame, text="Reel Timeout (sec):").grid(row=2, column=0)
        ttk.Entry(settings_frame, textvariable=self.reel_timeout, width=5).grid(row=2, column=1, sticky="w")
        
        # Checkbox to disable casting
        ttk.Checkbutton(settings_frame, text="Detect Only (No Casting)", variable=self.disable_casting).grid(row=3, column=0, columnspan=2, sticky="w", padx=5, pady=5)
        
        # --- Sensitivity & Splash Meter ---
        sens_frame = ttk.LabelFrame(root, text="Splash Detection")
        sens_frame.pack(fill="x", padx=10, pady=5)

        ttk.Label(sens_frame, text="Sensitivity:").pack(anchor="w", padx=5, pady=(5,0))
        scale = ttk.Scale(sens_frame, variable=self.sensitivity, from_=0.5, to=15.0)
        scale.pack(fill="x", padx=5, pady=(0,2))
        
        # Helper label to show slider value
        self.lbl_sens_val = ttk.Label(sens_frame, text="2.0")
        self.lbl_sens_val.pack(anchor="e", padx=5, pady=(0,5))
        # Link slider movement to label update
        scale.configure(command=lambda v: self.lbl_sens_val.configure(text=f"{float(v):.2f}"))

        self.splash_bar = ttk.Progressbar(sens_frame, variable=self.current_splash_val, maximum=15.0)
        self.splash_bar.pack(fill="x", padx=5, pady=(0,2))
        self.lbl_splash_val = ttk.Label(sens_frame, text="Noise: 0.0")
        self.lbl_splash_val.pack(anchor="e", padx=5, pady=(0,5))

        # --- Zone & Calib ---
        zone_frame = ttk.LabelFrame(root, text="Detection Area")
        zone_frame.pack(fill="x", padx=10, pady=5)
        
        self.lbl_zone = ttk.Label(zone_frame, text=f"Zone: {self.zone}")
        self.lbl_zone.pack(pady=5)
        
        btn_zone = ttk.Button(zone_frame, text="1. Select Screen Zone", command=self.start_zone_selection)
        btn_zone.pack(pady=5)

        btn_template = ttk.Button(zone_frame, text="2. Calibrate Bobber (Template)", command=self.create_template_guide)
        btn_template.pack(pady=5)
        
        tmpl_text = "Template Loaded!" if os.path.exists(self.template_path) else "No template loaded"
        self.lbl_template = ttk.Label(zone_frame, text=tmpl_text)
        self.lbl_template.pack()

        # --- Start/Stop ---
        control_frame = ttk.Frame(root)
        control_frame.pack(fill="x", padx=10, pady=10)
        
        self.btn_start = ttk.Button(control_frame, text="START BOT", command=self.toggle_bot)
        self.btn_start.pack(fill="x", ipady=10)

    # --- SAVE / LOAD LOGIC ---
    def load_config(self):
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r') as f:
                    data = json.load(f)
                    self.zone = data.get('zone', self.zone)
                    self.window_title.set(data.get('window_title', "World of Warcraft"))
                    self.cast_key.set(data.get('cast_key', "1"))
                    self.interact_key.set(data.get('interact_key', "9"))
                    self.sensitivity.set(data.get('sensitivity', 2.0))
                    self.reel_timeout.set(data.get('reel_timeout', 30))
                    self.disable_casting.set(data.get('disable_casting', False))
                    self.template_path = data.get('template_path', "bobber_template.png")
                    print("Config loaded.")
            except Exception as e:
                print(f"Failed to load config: {e}")

    def save_config(self):
        data = {
            'zone': self.zone,
            'window_title': self.window_title.get(),
            'cast_key': self.cast_key.get(),
            'interact_key': self.interact_key.get(),
            'sensitivity': self.sensitivity.get(),
            'reel_timeout': self.reel_timeout.get(),
            'disable_casting': self.disable_casting.get(),
            'template_path': self.template_path
        }
        try:
            with open(self.config_file, 'w') as f:
                json.dump(data, f)
            print("Config saved.")
        except Exception as e:
            print(f"Failed to save config: {e}")

    # --- Actions ---
    def log(self, msg):
        # Logging removed for minimal UI
        pass

    def update_splash_ui(self, val):
        # Update progress bar and text label safely
        # Note: If updating from thread, it's safer to use after(), 
        # but Tkinter variables are generally thread-safe enough for display updates like this
        self.current_splash_val.set(val)
        self.lbl_splash_val.config(text=f"Noise: {val:.2f}")

    def update_preview(self, cv_img):
        # Preview removed for minimal UI
        pass

    def toggle_bot(self):
        if self.bot_thread and self.bot_thread.is_alive():
            self.bot_thread.stop()
            self.btn_start.config(text="START BOT")
            self.log("Stopping bot...")
        else:
            self.save_config()
            config = {
                'window_title': self.window_title.get(),
                'zone': self.zone,
                'cast_key': self.cast_key.get(),
                'interact_key': self.interact_key.get(),
                'sensitivity': self.sensitivity.get(),
                'reel_timeout': int(self.reel_timeout.get()),
                'disable_casting': self.disable_casting.get(),
                'template_path': self.template_path
            }
            # Pass the splash UI updater function to the thread
            self.bot_thread = FishingBotThread(config, self.log, self.update_preview, self.update_splash_ui, self.update_overlay, self.update_timeout_ui)
            self.bot_thread.start()
            self.btn_start.config(text="STOP BOT")

    # --- Overlay & Timeout UI helpers ---
    def _init_overlay(self):
        if self.overlay_win:
            return
        try:
            self.overlay_win = tk.Toplevel(self.root)
            self.overlay_win.overrideredirect(True)
            self.overlay_win.attributes('-topmost', True)
            # Transparent color trick (Windows)
            self.overlay_win.config(bg='magenta')
            self.overlay_win.attributes('-transparentcolor', 'magenta')
            self.overlay_canvas = tk.Canvas(self.overlay_win, width=80, height=80, bg='magenta', highlightthickness=0)
            self.overlay_canvas.pack()
            self.overlay_rect = self.overlay_canvas.create_rectangle(5, 5, 75, 75, outline='lime', width=2)
            self.overlay_text = self.overlay_canvas.create_text(40, 40, text='', fill='white')
            self.overlay_win.withdraw()
        except Exception:
            # if transparency isn't supported or error happens, fall back to simple toplevel
            self.overlay_win = tk.Toplevel(self.root)
            self.overlay_win.overrideredirect(True)
            self.overlay_win.attributes('-topmost', True)
            self.overlay_canvas = tk.Canvas(self.overlay_win, width=80, height=80, bg='black', highlightthickness=0)
            self.overlay_canvas.pack()
            self.overlay_rect = self.overlay_canvas.create_rectangle(5, 5, 75, 75, outline='lime', width=2)
            self.overlay_text = self.overlay_canvas.create_text(40, 40, text='', fill='white')
            self.overlay_win.withdraw()

    def _show_overlay(self, x, y, confidence):
        self._init_overlay()
        w, h = 80, 80
        left = int(x - w//2)
        top = int(y - h//2)
        self.overlay_win.geometry(f"{w}x{h}+{left}+{top}")
        percent = int(confidence * 100)
        try:
            self.overlay_canvas.itemconfigure(self.overlay_text, text=f"Bobber\n{percent}%")
            # Color based on accuracy
            color = 'lime' if confidence > 0.6 else 'yellow' if confidence > 0.3 else 'red'
            self.overlay_canvas.itemconfigure(self.overlay_rect, outline=color)
        except Exception:
            pass
        self.overlay_win.deiconify()

    def _hide_overlay(self):
        if self.overlay_win:
            try:
                self.overlay_win.withdraw()
            except Exception:
                pass

    def update_overlay(self, x, y, confidence):
        # Called from worker thread; schedule on main loop
        if x is None or y is None:
            try:
                self.root.after(0, self._hide_overlay)
            except Exception:
                pass
            return
        try:
            self.root.after(0, lambda: self._show_overlay(x, y, confidence))
        except Exception:
            pass

    def update_timeout_ui(self, remaining_sec):
        # Timeout UI removed for minimal UI
        pass

    # --- Zone Selection ---
    def start_zone_selection(self):
        self.root.withdraw()
        self.sel_win = tk.Toplevel(self.root)
        self.sel_win.attributes('-fullscreen', True)
        self.sel_win.attributes('-alpha', 0.3)
        self.sel_win.attributes('-topmost', True)
        self.sel_win.config(bg='grey')
        
        self.canvas = tk.Canvas(self.sel_win, cursor="cross", bg="grey")
        self.canvas.pack(fill="both", expand=True)
        
        self.start_x = None
        self.start_y = None
        self.rect = None
        
        self.canvas.bind("<ButtonPress-1>", self.on_press)
        self.canvas.bind("<B1-Motion>", self.on_drag)
        self.canvas.bind("<ButtonRelease-1>", self.on_release_zone)

    def on_press(self, event):
        self.start_x = event.x
        self.start_y = event.y
        self.rect = self.canvas.create_rectangle(self.start_x, self.start_y, event.x, event.y, outline='red', width=3)

    def on_drag(self, event):
        self.canvas.coords(self.rect, self.start_x, self.start_y, event.x, event.y)

    def on_release_zone(self, event):
        x1 = min(self.start_x, event.x)
        y1 = min(self.start_y, event.y)
        x2 = max(self.start_x, event.x)
        y2 = max(self.start_y, event.y)
        
        self.zone = {'left': x1, 'top': y1, 'width': x2-x1, 'height': y2-y1}
        self.lbl_zone.config(text=f"Zone: {self.zone}")
        self.save_config()
        self.sel_win.destroy()
        self.root.deiconify()

    # --- Calibration ---
    def create_template_guide(self):
        if self.bot_thread and self.bot_thread.is_alive():
            messagebox.showerror("Error", "Stop the bot before calibrating!")
            return
        self.log("Cast your line now! Taking snapshot in 3s...")
        self.root.after(3000, self.open_calibration_window)

    def open_calibration_window(self):
        try:
            with mss.mss() as sct:
                monitor = {
                    "top": int(self.zone['top']), 
                    "left": int(self.zone['left']), 
                    "width": int(self.zone['width']), 
                    "height": int(self.zone['height'])
                }
                sct_img = sct.grab(monitor)
                self.cal_np_img = np.array(sct_img)
                img = Image.frombytes("RGB", sct_img.size, sct_img.bgra, "raw", "BGRX")
        except Exception as e:
            self.log(f"Screen grab failed: {e}")
            return

        self.cal_win = tk.Toplevel(self.root)
        self.cal_win.title("Draw Box Around Bobber (Release mouse to save)")
        self.cal_win.attributes('-topmost', True)
        
        self.cal_photo = ImageTk.PhotoImage(img)
        self.cal_canvas = tk.Canvas(self.cal_win, width=img.width, height=img.height, cursor="cross")
        self.cal_canvas.pack()
        self.cal_canvas.create_image(0, 0, image=self.cal_photo, anchor=tk.NW)

        self.cal_start_x = 0
        self.cal_start_y = 0
        self.cal_rect = None

        self.cal_canvas.bind("<ButtonPress-1>", self.cal_on_press)
        self.cal_canvas.bind("<B1-Motion>", self.cal_on_drag)
        self.cal_canvas.bind("<ButtonRelease-1>", self.cal_on_release)

    def cal_on_press(self, event):
        self.cal_start_x = event.x
        self.cal_start_y = event.y
        self.cal_rect = self.cal_canvas.create_rectangle(event.x, event.y, event.x, event.y, outline='green', width=2)

    def cal_on_drag(self, event):
        self.cal_canvas.coords(self.cal_rect, self.cal_start_x, self.cal_start_y, event.x, event.y)

    def cal_on_release(self, event):
        x1 = min(self.cal_start_x, event.x)
        y1 = min(self.cal_start_y, event.y)
        x2 = max(self.cal_start_x, event.x)
        y2 = max(self.cal_start_y, event.y)

        if (x2 - x1) > 5 and (y2 - y1) > 5:
            bgr_img = cv2.cvtColor(self.cal_np_img, cv2.COLOR_BGRA2BGR)
            template = bgr_img[y1:y2, x1:x2]
            cv2.imwrite("bobber_template.png", template)
            self.template_path = "bobber_template.png"
            self.lbl_template.config(text="Template Saved!", foreground="green")
            self.log("Bobber template saved.")
            self.save_config()
            self.cal_win.destroy()
            messagebox.showinfo("Success", "Bobber saved! Settings updated.")
        else:
            self.log("Selection too small, try again.")
            self.cal_canvas.delete(self.cal_rect)

if __name__ == "__main__":
    root = tk.Tk()
    app = FishingApp(root)
    root.mainloop()
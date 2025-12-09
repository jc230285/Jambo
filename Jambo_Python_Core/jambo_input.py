import time
import win32api
import win32con
import win32gui

_last_key_send = 0

def get_vk(key):
    key = key.upper()
    
    # F-Keys (F1-F24)
    if key.startswith("F") and len(key) > 1:
        try:
            # Check if the rest is a number
            if key[1:].isdigit():
                return win32con.VK_F1 + int(key[1:]) - 1
        except: 
            pass

    # Standard & Special Keys
    specials = {
        # Controls
        'TAB': 0x09, 
        'SPACE': 0x20,
        'ENTER': 0x0D,
        'ESCAPE': 0x1B,
        'BACKSPACE': 0x08,
        
        # Navigation
        'LEFT': 0x25, 'UP': 0x26, 'RIGHT': 0x27, 'DOWN': 0x28,
        'INSERT': 0x2D, 'DELETE': 0x2E,
        'HOME': 0x24, 'END': 0x23,
        'PAGEUP': 0x21, 'PAGEDOWN': 0x22,
        
        # Punctuation
        '-': 0xBD, '=': 0xBB, 
        '[': 0xDB, ']': 0xDD, '\\': 0xDC, 
        ';': 0xBA, "'": 0xDE, 
        ',': 0xBC, '.': 0xBE, '/': 0xBF,
        '`': 0xC0,

        # Numpad
        'NUMPAD0': 0x60, 'NUMPAD1': 0x61, 'NUMPAD2': 0x62,
        'NUMPAD3': 0x63, 'NUMPAD4': 0x64, 'NUMPAD5': 0x65,
        'NUMPAD6': 0x66, 'NUMPAD7': 0x67, 'NUMPAD8': 0x68, 'NUMPAD9': 0x69,
        'NUMPADMULT': 0x6A, 'NUMPADADD': 0x6B, 'NUMPADSUB': 0x6D, 
        'NUMPADDIV': 0x6F, 'NUMPADDEC': 0x6E,
    }
    
    if key in specials: 
        return specials[key]
    
    # Single Characters (A-Z, 0-9)
    if len(key) == 1: 
        return ord(key)
        
    return None

def send_key(key, duration=0.05):
    global _last_key_send
    
    # Global debounce (prevents spamming faster than 100ms)
    if time.time() - _last_key_send < 0.1: return
    _last_key_send = time.time()
    
    # --- SAFETY CHECKS ---
    # Do not press TAB or F4 if ALT is held (Prevents Alt-Tab / Alt-F4)
    if key.upper() in ["F4", "TAB"]:
        if win32api.GetAsyncKeyState(win32con.VK_MENU) & 0x8000:
            print(f"[Input] Blocked {key} (Alt is held)")
            return

    # Find WoW Window
    hwnd = win32gui.FindWindow(None, "World of Warcraft")
    if not hwnd:
        hwnd = win32gui.FindWindow(None, "World of Warcraft Classic")
    if not hwnd:
        hwnd = win32gui.FindWindow("GxWindowClass", None)
        
    if not hwnd: 
        print("[Input] Error: WoW Window not found")
        return

    # Parse Modifiers (Shift-1, Ctrl-F1, etc.)
    modifiers = []
    if "-" in key and len(key) > 1: 
        parts = key.split("-")
        key = parts[-1]
        if "SHIFT" in parts[0].upper(): modifiers.append(win32con.VK_SHIFT)
        if "CTRL" in parts[0].upper(): modifiers.append(win32con.VK_CONTROL)
        if "ALT" in parts[0].upper(): modifiers.append(win32con.VK_MENU)

    # If key refers to a mouse button (e.g. BUTTON1, BUTTON2, BUTTON4), send mouse messages
    k_upper = key.upper()
    if k_upper.startswith("BUTTON"):
        try:
            btn_num = int(k_upper.replace("BUTTON", ""))
        except Exception:
            print(f"[Input] Error: Unknown Mouse Button '{key}'")
            return

        # Compute center of window for click coordinates
        try:
            rect = win32gui.GetWindowRect(hwnd)
            left, top, right, bottom = rect
            cx = (right - left) // 2
            cy = (bottom - top) // 2
            lparam = win32api.MAKELONG(cx, cy)
        except Exception:
            cx = 1; cy = 1
            lparam = win32api.MAKELONG(cx, cy)

        # Press Modifiers first
        for mod in modifiers:
            win32api.PostMessage(hwnd, win32con.WM_KEYDOWN, mod, 0)

        # Dispatch mouse button messages
        if btn_num == 1:
            win32api.PostMessage(hwnd, win32con.WM_LBUTTONDOWN, win32con.MK_LBUTTON, lparam)
            time.sleep(duration)
            win32api.PostMessage(hwnd, win32con.WM_LBUTTONUP, 0, lparam)
        elif btn_num == 2:
            win32api.PostMessage(hwnd, win32con.WM_RBUTTONDOWN, win32con.MK_RBUTTON, lparam)
            time.sleep(duration)
            win32api.PostMessage(hwnd, win32con.WM_RBUTTONUP, 0, lparam)
        elif btn_num == 3:
            win32api.PostMessage(hwnd, win32con.WM_MBUTTONDOWN, win32con.MK_MBUTTON, lparam)
            time.sleep(duration)
            win32api.PostMessage(hwnd, win32con.WM_MBUTTONUP, 0, lparam)
        elif btn_num in (4, 5):
            # XBUTTON1/XBUTTON2: encode button in high word of wParam
            hi = 0x0001 if btn_num == 4 else 0x0002
            wParam = (hi << 16)
            WM_XDOWN = 0x020B
            WM_XUP = 0x020C
            win32api.PostMessage(hwnd, WM_XDOWN, wParam, lparam)
            time.sleep(duration)
            win32api.PostMessage(hwnd, WM_XUP, wParam, lparam)
        else:
            print(f"[Input] Error: Unsupported mouse button {btn_num}")

        # Release Modifiers
        for mod in reversed(modifiers): 
            win32api.PostMessage(hwnd, win32con.WM_KEYUP, mod, 0xC0000000)

        print(f"[Input] Sent mouse BUTTON{btn_num} (Hold: {duration}s)")
        return

    # Get Virtual Key Code
    vk = get_vk(key)
    if not vk: 
        print(f"[Input] Error: Unknown Key Definition for '{key}'")
        return

    # Generate Scan Code (Crucial for WoW input recognition)
    scan_code = win32api.MapVirtualKey(vk, 0)
    lparam_down = 1 | (scan_code << 16)
    lparam_up = 1 | (scan_code << 16) | (1 << 30) | (1 << 31)

    # 1. Press Modifiers
    for mod in modifiers: 
        win32api.PostMessage(hwnd, win32con.WM_KEYDOWN, mod, 0)
    
    # 2. Press Main Key
    win32api.PostMessage(hwnd, win32con.WM_KEYDOWN, vk, lparam_down)
    
    # 3. Hold Duration
    time.sleep(duration) 
    
    # 4. Release Main Key
    win32api.PostMessage(hwnd, win32con.WM_KEYUP, vk, lparam_up)
    
    # 5. Release Modifiers
    for mod in reversed(modifiers): 
        win32api.PostMessage(hwnd, win32con.WM_KEYUP, mod, 0xC0000000)
    
    print(f"[Input] Sent: {key} (Hold: {duration}s)")
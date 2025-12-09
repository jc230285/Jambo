import sys
import os
import time
import math
import random
import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from pathlib import Path
import shutil
import tempfile
import urllib.request
import zipfile
import json

def ensure_repo(addon_dir: str, repo_url: str = 'https://github.com/jc230285/Jambo', force_install: bool = False, log_fn=None) -> bool:
    """Download and extract addon files from GitHub without requiring git."""
    try:
        # Convert github repo URL to zip download URL
        # https://github.com/jc230285/Jambo -> https://github.com/jc230285/Jambo/archive/refs/heads/beta.zip
        zip_url = f"{repo_url}/archive/refs/heads/beta.zip"
        
        if callable(log_fn):
            try: log_fn(f"[AUTO] Downloading addon from GitHub...", "Warn")
            except Exception: pass
        
        print(f"[AUTO] Downloading from: {zip_url}")
        
        # Download zip to temp file
        temp_zip = tempfile.mktemp(suffix='.zip')
        try:
            urllib.request.urlretrieve(zip_url, temp_zip)
            print(f"[AUTO] Downloaded to: {temp_zip}")
        except Exception as e:
            print(f"[AUTO] Download failed: {e}")
            if callable(log_fn):
                try: log_fn(f"[AUTO] Download failed: {e}", "Warn")
                except Exception: pass
            return False
        
        # Extract to temp folder
        temp_extract = tempfile.mkdtemp(prefix='jambo_extract_')
        try:
            with zipfile.ZipFile(temp_zip, 'r') as zip_ref:
                zip_ref.extractall(temp_extract)
            print(f"[AUTO] Extracted to: {temp_extract}")
        except Exception as e:
            print(f"[AUTO] Extract failed: {e}")
            if callable(log_fn):
                try: log_fn(f"[AUTO] Extract failed: {e}", "Warn")
                except Exception: pass
            os.remove(temp_zip)
            shutil.rmtree(temp_extract, ignore_errors=True)
            return False
        
        os.remove(temp_zip)
        
        # Find the extracted folder (will be like Jambo-beta/)
        extracted_folders = os.listdir(temp_extract)
        if not extracted_folders:
            print(f"[AUTO] No files extracted")
            if callable(log_fn):
                try: log_fn(f"[AUTO] No files extracted", "Warn")
                except Exception: pass
            shutil.rmtree(temp_extract, ignore_errors=True)
            return False
        
        source_folder = os.path.join(temp_extract, extracted_folders[0])
        print(f"[AUTO] Source folder: {source_folder}")
        
        # Copy ALL files and folders from the extracted repo into addon_dir
        # This will overwrite existing Jambo files but leave other addons alone
        try:
            if callable(log_fn):
                try: log_fn(f"[AUTO] Installing addon files to {addon_dir}...", "Warn")
                except Exception: pass
            
            print(f"[AUTO] Installing to: {addon_dir}")
            
            # Ensure target directory exists
            os.makedirs(addon_dir, exist_ok=True)
            
            # Copy all files and folders
            items = os.listdir(source_folder)
            print(f"[AUTO] Found {len(items)} items to copy")
            
            # Helper to handle read-only files
            def remove_readonly(func, path, exc_info):
                """Error handler for Windows readonly files"""
                import stat
                if not os.access(path, os.W_OK):
                    os.chmod(path, stat.S_IWUSR)
                    func(path)
                else:
                    raise
            
            for item in items:
                # Skip .git folders to avoid permission issues
                if item == '.git' or item == '.gitignore':
                    print(f"[AUTO] Skipping: {item}")
                    continue
                    
                source_path = os.path.join(source_folder, item)
                dest_path = os.path.join(addon_dir, item)
                
                try:
                    if os.path.isdir(source_path):
                        # Copy directory recursively
                        print(f"[AUTO] Copying folder: {item}")
                        if os.path.exists(dest_path):
                            print(f"[AUTO] Updating existing folder: {dest_path}")
                            # Use copytree with dirs_exist_ok=True to merge/overwrite
                            shutil.copytree(source_path, dest_path, dirs_exist_ok=True)
                        else:
                            shutil.copytree(source_path, dest_path)
                    else:
                        # Copy file
                        print(f"[AUTO] Copying file: {item}")
                        shutil.copy2(source_path, dest_path)
                except Exception as e:
                    print(f"[AUTO] Failed to copy {item}: {e}")
                    if callable(log_fn):
                        try: log_fn(f"[AUTO] Failed to copy {item}: {e}", "Warn")
                        except Exception: pass
            
            if callable(log_fn):
                try: log_fn(f"[AUTO] Addon installed successfully!", "Warn")
                except Exception: pass
            
        except Exception as e:
            print(f"[AUTO] Install failed: {e}")
            if callable(log_fn):
                try: log_fn(f"[AUTO] Install failed: {e}", "Warn")
                except Exception: pass
            shutil.rmtree(temp_extract, ignore_errors=True)
            return False
        
        shutil.rmtree(temp_extract, ignore_errors=True)
        return True
        
    except Exception as e:
        print(f"Ensure repo failed: {e}")
        if callable(log_fn):
            try: log_fn(f"[AUTO] Update check failed: {e}", "Warn")
            except Exception: pass
        return False

def get_default_branch(addon_dir: str) -> str:
    try:
        res = subprocess.run(["git", "remote", "show", "origin"], capture_output=True, text=True, cwd=addon_dir, creationflags=CREATE_NO_WINDOW)
        if res.returncode == 0 and res.stdout:
            for line in res.stdout.splitlines():
                if "HEAD branch" in line:
                    return line.split(":")[-1].strip()
    except Exception:
        pass
    return "main"

def get_addon_install_dir(root_dir: str) -> str:
    # Build the full path to the addon directory inside the WoW installation
    if not root_dir: return os.path.dirname(__file__)
    return os.path.join(root_dir, "Interface", "AddOns")
import subprocess
import threading
import win32api
import ctypes
from ctypes import wintypes
import subprocess as _subprocess

# Windows constant to prevent subprocess from creating console windows
CREATE_NO_WINDOW = 0x08000000

# --- Windows elevation helpers ---
def is_elevated() -> bool:
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False

def relaunch_as_admin(args: list[str] | None = None) -> bool:
    """Relaunch the current script as administrator (UAC). Returns True if launched, False otherwise."""
    try:
        params = []
        if args:
            params = args
        else:
            # Launch the same python executable with the same script path and current arguments
            script = os.path.abspath(sys.argv[0]) if len(sys.argv) > 0 else ''
            params = [script] + sys.argv[1:]
        # Build the command string
        cmd = ' '.join([f'"{p}"' for p in params])
        # Use ShellExecuteW with 'runas'
        SE_ERR = ctypes.windll.shell32.ShellExecuteW(None, 'runas', sys.executable, cmd, None, 1)
        # On success ShellExecute returns > 32
        return SE_ERR > 32
    except Exception as e:
        print(f"Relaunch as admin failed: {e}")
        return False

# Main overlay size constants (match screenshot size)
MAIN_WIN_W = 270
MAIN_WIN_H = 200

# --- TCL FIX ---
def _fix_tcl():
    base = Path(sys.base_prefix)
    tcl_path = None
    for p in [base / "tcl/tcl8.6", base / "Lib/tcl8.6", Path(os.path.dirname(sys.executable)) / "tcl/tcl8.6"]:
        if (p / "init.tcl").exists():
            tcl_path = p; break
    if tcl_path:
        os.environ["TCL_LIBRARY"] = str(tcl_path)
        tk_p = tcl_path.parent / "tk8.6"
        if (tk_p / "tk.tcl").exists(): os.environ["TK_LIBRARY"] = str(tk_p)

_fix_tcl()

# --- IMPORTS ---
try:
    import jambo_config as cfg
    import jambo_input as inp
    import jambo_scanner as scan
    import jambo_bindings as bind
except ImportError as e:
    messagebox.showerror("Error", f"Missing Module: {e}")
    sys.exit(1)

# --- DATA MAP ---
FIELD_MAP = {
    0: "Checksum", 1: "SlotID", 2: "Priority", 3: "PlayerHP", 4: "PlayerRes",
    5: "ResType", 6: "TargetHP", 7: "TargetEnemy", 8: "MapLo", 9: "MapHi",
    10: "XLo", 11: "XHi", 12: "YLo", 13: "YHi", 14: "Facing",
    15: "MoneyLo", 16: "MoneyHi", 17: "Combat"
}

# --- INSPECTOR WINDOW ---
class InspectorWindow(tk.Toplevel):
    def __init__(self, parent):
        super().__init__(parent)
        self.title("Data Inspector")
        self.config(bg="#1a1a1a")
        self.attributes("-topmost", True)
        self.geometry("340x500")
        self.parent = parent
        self.style = ttk.Style(); self.style.theme_use('clam'); self.style.configure("TLabel", background="#1a1a1a", foreground="#eee")
        self._build_visuals()
        self._build_table()

    def _build_visuals(self):
        dash = tk.Frame(self, bg="#222", bd=1, relief="solid"); dash.pack(fill="x", padx=5, pady=5)
        bar_frame = tk.Frame(dash, bg="#222"); bar_frame.pack(fill="x", padx=5, pady=5)
        tk.Label(bar_frame, text="HP", bg="#222", fg="#fff", font=("Consolas", 8)).grid(row=0, column=0, sticky="e")
        self.bar_hp = ttk.Progressbar(bar_frame, length=200, mode="determinate"); self.bar_hp.grid(row=0, column=1, padx=5, pady=2)
        tk.Label(bar_frame, text="PP", bg="#222", fg="#fff", font=("Consolas", 8)).grid(row=1, column=0, sticky="e")
        self.bar_pp = ttk.Progressbar(bar_frame, length=200, mode="determinate"); self.bar_pp.grid(row=1, column=1, padx=5, pady=2)
        loc_frame = tk.Frame(dash, bg="#222"); loc_frame.pack(fill="x", padx=5, pady=5)
        self.canvas_compass = tk.Canvas(loc_frame, width=40, height=40, bg="#000", highlightthickness=0); self.canvas_compass.pack(side="left", padx=5)
        self.canvas_compass.create_oval(2, 2, 38, 38, outline="#444")
        self.compass_line = self.canvas_compass.create_line(20, 20, 20, 5, fill="#00ff00", width=2)
        self.lbl_zone = tk.Label(loc_frame, text="Zone: 0\nLoc: 0, 0", bg="#222", fg="#aaa", justify="left", font=("Consolas", 9)); self.lbl_zone.pack(side="left", padx=10)

    def _build_table(self):
        columns = ("idx", "name", "value"); self.tree = ttk.Treeview(self, columns=columns, show="headings", selectmode="browse", height=15)
        self.tree.heading("idx", text="#"); self.tree.column("idx", width=30, anchor="center")
        self.tree.heading("name", text="Field"); self.tree.column("name", width=120, anchor="w")
        self.tree.heading("value", text="Value"); self.tree.column("value", width=80, anchor="center")
        self.tree.pack(fill="both", expand=True, padx=5, pady=5)
        self.rows = []
        for i in range(len(FIELD_MAP)): self.rows.append(self.tree.insert("", "end", values=(i, FIELD_MAP[i], "-")))

    def update_data(self, vals):
        if not vals or len(vals) < 18: return
        for i, item in enumerate(self.rows):
            if i < len(vals): self.tree.item(item, values=(i, FIELD_MAP.get(i, "?"), vals[i]))
        in_combat = vals[17] == 1
        self.lbl_combat.config(bg="#ff0000", fg="#fff" if in_combat else "#555", text="COMBAT" if in_combat else "SAFE")
        self.bar_hp['value'] = vals[3] / 255.0 * 100
        self.bar_pp['value'] = vals[4] / 255.0 * 100
        ms = (vals[16] * 256) + vals[15]; self.lbl_gold.config(text=f"{ms//100}g {ms%100}s")
        mid = (vals[9] * 256) + vals[8]
        x = ((vals[11] * 256) + vals[10]) / 1000.0
        y = ((vals[13] * 256) + vals[12]) / 1000.0
        self.lbl_zone.config(text=f"Map: {mid}\n{x:.2f}, {y:.2f}")
        angle = (vals[14] / 255.0) * (2 * math.pi)
        dx = -math.sin(angle) * 15; dy = -math.cos(angle) * 15
        self.canvas_compass.coords(self.compass_line, 20, 20, 20+dx, 20+dy)

# --- OPTIONS WINDOW ---
class OptionsWindow(tk.Toplevel):
    def __init__(self, parent):
        super().__init__(parent)
        self.title("Options"); self.config(bg="#222"); self.attributes("-topmost", True); self.geometry("400x500"); self.parent = parent
        style = ttk.Style(); style.theme_use('clam'); style.configure("TLabel", background="#222", foreground="#eee")
        self._build_ui(); self._load_values()

    def _build_ui(self):
        pad = {'padx': 10, 'pady': 5}
        
        # Set Square Area at the top
        tk.Button(self, text="Set Square Area", bg="#0055aa", fg="white", command=self.parent._set_square).pack(fill="x", **pad)
        
        # WoW Folder
        ttk.Label(self, text="WoW Folder:").pack(anchor="w", **pad)
        folder_frame = tk.Frame(self, bg="#222"); folder_frame.pack(fill="x", **pad)
        tk.Button(folder_frame, text="Select", bg="#444", fg="white", command=self._select_folder).pack(side="left")
        self.lbl_folder = tk.Label(folder_frame, text=self.parent.config_data.get("root_dir", ""), bg="#333", fg="#eee", anchor="w", font=("Consolas", 8)); self.lbl_folder.pack(side="left", fill="x", expand=True, padx=(5,0))
        
        # Git Branch
        ttk.Label(self, text="Git Branch:").pack(anchor="w", **pad)
        branch_frame = tk.Frame(self, bg="#222"); branch_frame.pack(fill="x", **pad)
        self.cb_branch = ttk.Combobox(branch_frame, state="readonly"); self.cb_branch.pack(side="left", fill="x", expand=True)
        self.lbl_git_status = tk.Label(branch_frame, text="", bg="#222", fg="#bbb", font=("Consolas",8)); self.lbl_git_status.pack(side="right")
        self.cb_branch.bind("<<ComboboxSelected>>", self._on_branch_change)
        tk.Button(branch_frame, text="Check Updates", bg="#444", fg="white", command=self._check_updates).pack(side="right", padx=(5,0))
        
        # Account
        ttk.Label(self, text="Account:").pack(anchor="w", **pad)
        self.cb_account = ttk.Combobox(self, state="readonly"); self.cb_account.pack(fill="x", **pad)
        self.cb_account.bind("<<ComboboxSelected>>", self._on_account_change)
        
        # Character
        ttk.Label(self, text="Character:").pack(anchor="w", **pad)
        self.cb_char = ttk.Combobox(self, state="readonly"); self.cb_char.pack(fill="x", **pad)
        self.cb_char.bind("<<ComboboxSelected>>", self._on_char_change)

    def _load_values(self):
        root = self.parent.config_data.get("root_dir", "")
        
        # Load branches - set beta as default
        addon_dir = get_addon_install_dir(root)
        branches = ["beta", "master"]  # Always show beta and master
        self.cb_branch["values"] = branches
        current = self._get_current_branch(addon_dir)
        if current in branches:
            self.cb_branch.set(current)
        else:
            self.cb_branch.set("beta")  # Default to beta
        
        # Show git status
        try:
            if os.path.isdir(os.path.join(addon_dir, '.git')):
                self.lbl_git_status.config(text="Git: repo detected")
            else:
                self.lbl_git_status.config(text="Git: No repo — using default branches")
        except Exception:
            pass
        
        # Load accounts
        accts = bind.get_accounts(root)
        self.cb_account["values"] = accts
        saved = self.parent.config_data.get("selected_account", "")
        if saved in accts:
            self.cb_account.set(saved)
            self._on_account_change(None, skip_save=True)
        elif accts:
            # Auto-select first account if none saved
            self.cb_account.set(accts[0])
            self._on_account_change(None, skip_save=False)

    def _on_account_change(self, event, skip_save=False):
        root = self.parent.config_data.get("root_dir", "")
        acct = self.cb_account.get()
        chars = bind.get_characters(root, acct)
        self.cb_char["values"] = chars
        saved = self.parent.config_data.get("selected_character", "")
        if saved in chars:
            self.cb_char.set(saved)
        elif chars:
            # Auto-select first character if none saved
            self.cb_char.set(chars[0])
            if not skip_save:
                self.parent.config_data["selected_character"] = chars[0]
        else:
            self.cb_char.set("")
        if not skip_save:
            self.parent.config_data["selected_account"] = acct
            cfg.save(self.parent.config_data)
            self.parent._load_bindings()

    def _on_char_change(self, event):
        self.parent.config_data["selected_character"] = self.cb_char.get()
        cfg.save(self.parent.config_data)
        self.parent._load_bindings()

    def _select_folder(self):
        folder = filedialog.askdirectory(title="Select World of Warcraft Folder", initialdir=self.parent.config_data.get("root_dir", ""))
        if folder:
            self.parent.config_data["root_dir"] = folder
            cfg.save(self.parent.config_data)
            self.lbl_folder.config(text=folder)
            self._load_values()  # Reload accounts with new path

    def _get_current_branch(self, cwd=None):
        try:
            if not cwd: cwd = os.path.dirname(__file__)
            result = subprocess.run(["git", "branch", "--show-current"], capture_output=True, text=True, cwd=cwd, creationflags=CREATE_NO_WINDOW)
            if result.returncode == 0:
                return result.stdout.strip()
        except Exception as e:
            print(f"Error getting current branch: {e}")
        return ""

    def _on_branch_change(self, event):
        branch = self.cb_branch.get()
        if branch:
            try:
                addon_dir = get_addon_install_dir(self.parent.config_data.get("root_dir", ""))
                branch_to_checkout = branch
                if branch == "default":
                    branch_to_checkout = get_default_branch(addon_dir)
                subprocess.run(["git", "checkout", branch_to_checkout], cwd=addon_dir, creationflags=CREATE_NO_WINDOW)
                messagebox.showinfo("Branch Changed", f"Switched to branch: {branch}")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to switch branch: {e}")

    def _check_updates(self):
        try:
            addon_dir = get_addon_install_dir(self.parent.config_data.get("root_dir", ""))
            # If not a repo, try to clone (auto-download)
            if not os.path.isdir(os.path.join(addon_dir, '.git')):
                ensure_repo(addon_dir, force_install=True, log_fn=self.parent._log_raw)
            # Fetch latest
            try:
                self.parent._log_raw(f"[AUTO] Fetching updates for {addon_dir}...", "Warn")
            except Exception:
                pass
            subprocess.run(["git", "fetch"], cwd=addon_dir, creationflags=CREATE_NO_WINDOW)
            # Check if behind
            result = subprocess.run(["git", "status", "-uno"], capture_output=True, text=True, cwd=addon_dir, creationflags=CREATE_NO_WINDOW)
            if "behind" in result.stdout:
                # Pull
                try:
                    self.parent._log_raw(f"[AUTO] Pulling updates to {addon_dir}...", "Warn")
                except Exception:
                    pass
                pull_result = subprocess.run(["git", "pull"], cwd=addon_dir, creationflags=CREATE_NO_WINDOW)
                if pull_result.returncode == 0:
                    # Push updates to beta branch
                    subprocess.run(["git", "push"], cwd=addon_dir, creationflags=CREATE_NO_WINDOW)
                    messagebox.showinfo("Update", "Addon updated successfully!")
                else:
                    messagebox.showerror("Update Failed", "Failed to pull updates.")
            else:
                messagebox.showinfo("No Updates", "Addon is up to date.")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to check updates: {e}")

# --- MAIN OVERLAY ---
class Overlay(tk.Tk):
    def __init__(self):
        super().__init__()
        # Remove window decorations and set transparency
        try:
            self.overrideredirect(True)
        except Exception:
            pass
        self.attributes("-topmost", True); self.attributes("-alpha", 0.8); self.config(bg="#111")
        self.config_data = cfg.load()
        # Validate stored window position and clamp to screen bounds if out of range
        default_x = self.config_data.get('window_x', 50)
        default_y = self.config_data.get('window_y', 50)
        try:
            # Create root first and compute screen bounds
            screen_w = self.winfo_screenwidth(); screen_h = self.winfo_screenheight()
            win_w, win_h = MAIN_WIN_W, MAIN_WIN_H
            x = int(default_x)
            y = int(default_y)
            # If coordinates are massively off-screen, reset them
            if x < -win_w or y < -win_h or x > screen_w or y > screen_h:
                print(f"[Overlay] Saved window position out of bounds: {default_x},{default_y} resetting to 50,50")
                x, y = 50, 50
                self.config_data['window_x'] = x; self.config_data['window_y'] = y
                cfg.save(self.config_data)
        except Exception:
            x, y = default_x, default_y
        self.geometry(f"{win_w}x{win_h}+{x}+{y}")
        self.current_pos = cfg.load_pos(); self.slot_map = {}; self.action_map = {}; self.auto_ability = False; self.auto_target = False
        self.opt_window = None; self.insp_window = None
        self.press_history = []; self.shown_warnings = set()
        self._last_log_ability = ""; self._last_log_target = ""
        self._drag_data = {"x": 0, "y": 0}
        
        # Cycle State: 0=Ability, 1=Target
        self._cycle_phase = 0
        
        # Auto update thread
        self.auto_update_thread = threading.Thread(target=self._auto_update_loop, daemon=True)
        self.auto_update_thread.start()
        # Start a dedicated key monitor thread for toggle/pause key
        self._key_monitor_thread = threading.Thread(target=self._key_monitor_loop, daemon=True)
        self._key_monitor_thread.start()
        # Install low-level keyboard hook for reliable short-press detection on Windows
        try:
            self.hook_installed = False
            self._hook_thread = threading.Thread(target=self._install_keyboard_hook, daemon=True)
            self._hook_thread.start()
        except Exception:
            self.hook_installed = False
        # Toggle / pause key handling (grave/backtick key)
        # Use jambo_input helper to get VK code
        # Start with any pre-configured true VK from config
        self.toggle_vk = self.config_data.get('toggle_vk', 0)
        self._toggle_last_state = 0
        self.pause_targeting = False
        
        self.bind("<ButtonPress-1>", self._start_move); self.bind("<B1-Motion>", self._do_move); self.bind("<ButtonRelease-1>", self._stop_move)
        self._build_overlay_ui(); self._load_bindings()
        self.after(100, self._refresh_loop)
        # Check for updates after UI has loaded
        self.after(1000, self._check_updates_on_startup)
        print("Overlay window created successfully")

    def _build_overlay_ui(self):
        c = tk.Frame(self, bg="#111"); c.pack(fill="both", expand=True, padx=2, pady=2)
        self.lbl_status = tk.Label(c, text="Jambo Python Ready", bg="#111", fg="#00aaff", font=("Segoe UI", 10, "bold")); self.lbl_status.pack(fill="x", pady=(2,0))
        self.lbl_status.bind("<ButtonPress-1>", self._start_move); self.lbl_status.bind("<B1-Motion>", self._do_move)
        self.lbl_warning = tk.Label(c, text="", bg="#111", fg="#ff4444", font=("Consolas", 8)); self.lbl_warning.pack(fill="x", pady=(0, 2))
        self.lbl_warning.bind("<ButtonPress-1>", self._start_move); self.lbl_warning.bind("<B1-Motion>", self._do_move)
        
        log_frame = tk.Frame(c, bg="#000", bd=1, relief="sunken")
        log_frame.pack(fill="both", expand=True, padx=4, pady=0)
        self.txt_log = tk.Text(log_frame, height=6, width=40, bg="#000", font=("Consolas", 8), borderwidth=0, highlightthickness=0, state="disabled", spacing1=1)
        self.txt_log.pack(fill="both", expand=True)
        self.txt_log.tag_config("Ability", foreground="#00ff00"); self.txt_log.tag_config("Target", foreground="#00bfff"); self.txt_log.tag_config("Warn", foreground="#ff4444")
        self.txt_log.bind("<ButtonPress-1>", self._start_move); self.txt_log.bind("<B1-Motion>", self._do_move)
        # Monitored VK and state indicator
        # Monitored VK indicator (hidden by default) - removed to keep UI clean

        row1 = tk.Frame(c, bg="#111"); row1.pack(side="bottom", fill="x", pady=(2,0))
        opts = {"side": "left", "fill": "x", "expand": True, "padx": 1}
        tk.Button(row1, text="Exit", bg="#442222", fg="white", command=self._quit_app).pack(**opts)
        tk.Button(row1, text="Update", bg="#333", fg="white", command=self._force_update).pack(**opts)
        tk.Button(row1, text="Options", bg="#333", fg="white", command=self._toggle_options).pack(**opts)
        tk.Button(row1, text="Inspector", bg="#333", fg="#00aaff", command=self._toggle_inspector).pack(**opts)
        
        row2 = tk.Frame(c, bg="#111"); row2.pack(side="bottom", fill="x", pady=(4,0))
        self.btn_ability = tk.Button(row2, text="Ability", bg="#550000", fg="white", command=self._toggle_ability); self.btn_ability.pack(**opts)
        self.btn_target = tk.Button(row2, text="Target", bg="#550000", fg="white", command=self._toggle_target); self.btn_target.pack(**opts)

    def _start_move(self, event): self._drag_data = {"x": event.x, "y": event.y}
    def _do_move(self, event):
        x = self.winfo_x() + (event.x - self._drag_data["x"]); y = self.winfo_y() + (event.y - self._drag_data["y"])
        self.geometry(f"+{x}+{y}")
    def _stop_move(self, event):
        self.config_data.update({'window_x': self.winfo_x(), 'window_y': self.winfo_y()}); cfg.save(self.config_data)

    def _quit_app(self):
        try:
            self._uninstall_keyboard_hook()
        except Exception:
            pass
        self.destroy(); sys.exit()
    
    def _force_update(self):
        """Force update addons from git."""
        try:
            addon_dir = get_addon_install_dir(self.config_data.get("root_dir", ""))
            self._log_raw("[UPDATE] Force updating from git...", "Warn")
            
            # Try git pull first
            if os.path.isdir(os.path.join(addon_dir, '.git')):
                try:
                    subprocess.run(["git", "fetch"], cwd=addon_dir, creationflags=CREATE_NO_WINDOW, check=True)
                    subprocess.run(["git", "reset", "--hard", "origin/beta"], cwd=addon_dir, creationflags=CREATE_NO_WINDOW, check=True)
                    subprocess.run(["git", "pull"], cwd=addon_dir, creationflags=CREATE_NO_WINDOW, check=True)
                    self._log_raw("[UPDATE] Git update successful!", "Warn")
                    return
                except Exception as e:
                    self._log_raw(f"[UPDATE] Git failed: {e}, trying download...", "Warn")
            
            # Fallback to download
            if ensure_repo(addon_dir, force_install=True, log_fn=self._log_raw):
                self._log_raw("[UPDATE] Download update successful!", "Warn")
            else:
                self._log_raw("[UPDATE] Update failed!", "Warn")
        except Exception as e:
            self._log_raw(f"[UPDATE] Error: {e}", "Warn")
    
    def _toggle_options(self):
        if not self.opt_window or not tk.Toplevel.winfo_exists(self.opt_window): self.opt_window = OptionsWindow(self)
        else: self.opt_window.lift()
    def _toggle_inspector(self):
        if not self.insp_window or not tk.Toplevel.winfo_exists(self.insp_window): self.insp_window = InspectorWindow(self)
        else: self.insp_window.lift()
    def _toggle_ability(self):
        self.auto_ability = not self.auto_ability; self.btn_ability.config(bg="#005500" if self.auto_ability else "#550000", text="Ability: ON" if self.auto_ability else "Ability")
    def _toggle_target(self):
        self.auto_target = not self.auto_target; self.btn_target.config(bg="#005500" if self.auto_target else "#550000", text="Target: ON" if self.auto_target else "Target")

    def _set_square(self):
        sel = tk.Toplevel(self); sel.attributes("-fullscreen", True, "-alpha", 0.3, "-topmost", True); sel.config(bg="black")
        cv = tk.Canvas(sel, bg="black", cursor="crosshair", highlightthickness=0); cv.pack(fill="both", expand=True)
        s = [None]
        def down(e): s[0] = (e.x, e.y)
        def drag(e): 
            if s[0]: cv.delete("s"); cv.create_rectangle(s[0][0], s[0][1], e.x, e.y, outline="#0f0", width=2, tags="s")
        def up(e):
            if s[0]:
                l, t = min(s[0][0], e.x), min(s[0][1], e.y); sz = max(abs(e.x-s[0][0]), abs(e.y-s[0][1]))
                if sz > 10: self.config_data["square_size"] = sz; self.current_pos = cfg.save_pos((l, t)); cfg.save(self.config_data)
            sel.destroy()
        cv.bind("<ButtonPress-1>", down); cv.bind("<B1-Motion>", drag); cv.bind("<ButtonRelease-1>", up); sel.bind("<Escape>", lambda e: sel.destroy())

    def _load_bindings(self):
        root = self.config_data.get("root_dir", ""); acct = self.config_data.get("selected_account", ""); char = self.config_data.get("selected_character", "")
        if acct:
            self.slot_map, self.action_map = bind.load_bindings(root, acct, char)
            print(f"Loaded {len(self.slot_map)} bindings."); self.shown_warnings.clear(); self.lbl_warning.config(text="")

    def _log_warning(self, msg):
        self.lbl_warning.config(text=f"[!] {msg}")
        if msg in self.shown_warnings: return
        self.shown_warnings.add(msg); self._log_raw(f"[!] {msg}", "Warn")

    def _log_action(self, cat, val, key):
        comp = f"{val}:{key}"
        if cat == "Ability":
            if comp == self._last_log_ability: return
            self._last_log_ability = comp
        elif cat == "Target":
            if comp == self._last_log_target: return
            self._last_log_target = comp
        ts = time.strftime("%H:%M:%S"); self._log_raw(f"{ts} [{cat}] ({val}) {key}", cat)

    def _log_raw(self, text, tag):
        # Safe check - UI might not be ready yet
        if not hasattr(self, 'txt_log') or self.txt_log is None:
            print(f"[{tag}] {text}")
            return
        self.txt_log.config(state="normal"); self.txt_log.insert("end", text + "\n", tag)
        if int(self.txt_log.index('end-1c').split('.')[0]) > 6: self.txt_log.delete("1.0", "2.0")
        self.txt_log.see("end"); self.txt_log.config(state="disabled")

    def _check_updates_on_startup(self):
        """Check for updates after UI has loaded - runs in background."""
        def _check():
            try:
                addon_dir = get_addon_install_dir(self.config_data.get('root_dir', ''))
                print(f"[AUTO] Checking addon GitHub for updates...")
                print(f"[AUTO] Addon install directory: {addon_dir}")
                print(f"[AUTO] Downloading latest addon version...")
                if ensure_repo(addon_dir, force_install=True, log_fn=None):
                    print("[AUTO] Addon updated successfully!")
                    self._log_raw("[AUTO] Addon updated on startup", "Warn")
                else:
                    print("[AUTO] Addon update failed")
            except Exception as e:
                print(f"[AUTO] Update check failed: {e}")
        # Run in background thread so it doesn't block UI
        t = threading.Thread(target=_check, daemon=True)
        t.start()

    def _auto_update_loop(self):
        while True:
            time.sleep(60)  # Check every 60 seconds
            try:
                # Fetch
                addon_dir = get_addon_install_dir(self.config_data.get("root_dir", ""))
                subprocess.run(["git", "fetch"], cwd=addon_dir, capture_output=True, creationflags=CREATE_NO_WINDOW)
                # Check status
                result = subprocess.run(["git", "status", "-uno"], capture_output=True, text=True, cwd=addon_dir, creationflags=CREATE_NO_WINDOW)
                if "behind" in result.stdout:
                    # Pull
                    pull_result = subprocess.run(["git", "pull"], cwd=addon_dir, capture_output=True, creationflags=CREATE_NO_WINDOW)
                    if pull_result.returncode == 0:
                        # Push updates to beta branch
                        subprocess.run(["git", "push"], cwd=addon_dir, capture_output=True, creationflags=CREATE_NO_WINDOW)
                        self._log_raw("[AUTO] Addon updated from Git", "Warn")
                    else:
                        self._log_raw("[AUTO] Failed to update addon", "Warn")
            except Exception as e:
                print(f"Auto update error: {e}")

    def _key_monitor_loop(self):
        # Dedicated thread to monitor the toggle key at higher frequency
        last_state = 0
        print("[DEBUG] Key monitor thread started - watching VK 192 (grave key)")
        while True:
            try:
                # Always use grave key (192 = 0xC0) - no auto-detection
                vk = 192  # Grave/tilde key only
                
                state = win32api.GetAsyncKeyState(vk) & 0x8000
                
                # Debug output when key state changes
                if state != last_state:
                    print(f"[DEBUG] Grave key state changed: {last_state} -> {state}")
                
                # rising edge -> toggle ability
                if state and not last_state:
                    print("[DEBUG] Grave key pressed - toggling ability")
                    self.auto_ability = not self.auto_ability
                    # schedule UI update on main thread
                    try:
                        self.after(0, lambda: self.btn_ability.config(bg="#005500" if self.auto_ability else "#550000", text="Ability: ON" if self.auto_ability else "Ability"))
                    except Exception:
                        pass
                    # Ensure auto_target is disabled when toggling abilities
                    self.auto_target = False
                    try:
                        self.after(0, lambda: self.btn_target.config(bg="#550000", text="Target"))
                    except Exception:
                        pass
                self.pause_targeting = bool(state)
                last_state = state
            except Exception as e:
                print(f"[DEBUG] Key monitor exception: {e}")
            time.sleep(0.01)

    # Low-level keyboard hook for reliable detection of short presses
    def _install_keyboard_hook(self):
        try:
            user32 = ctypes.windll.user32
            kernel32 = ctypes.windll.kernel32
            WH_KEYBOARD_LL = 13
            WM_KEYDOWN = 0x0100
            WM_KEYUP = 0x0101
            WM_SYSKEYDOWN = 0x0104
            WM_SYSKEYUP = 0x0105

            class KBDLLHOOKSTRUCT(ctypes.Structure):
                _fields_ = [
                    ('vkCode', wintypes.DWORD),
                    ('scanCode', wintypes.DWORD),
                    ('flags', wintypes.DWORD),
                    ('time', wintypes.DWORD),
                    ('dwExtraInfo', ctypes.c_ulonglong)
                ]

            self._hook_last_state = {}

            @ctypes.WINFUNCTYPE(ctypes.c_long, ctypes.c_int, wintypes.WPARAM, wintypes.LPARAM)
            def low_level_keyboard_proc(nCode, wParam, lParam):
                try:
                    if nCode == 0:
                        kb = ctypes.cast(lParam, ctypes.POINTER(KBDLLHOOKSTRUCT)).contents
                        vk = kb.vkCode
                        # Detect keydown
                        if wParam == WM_KEYDOWN or wParam == WM_SYSKEYDOWN:
                            prev = self._hook_last_state.get(vk, False)
                            if not prev:
                                # rising edge, handle toggle and pause
                                # Only grave key (192 = 0xC0) - no auto-detection
                                if vk == 192:
                                    # toggle ability on keydown
                                    self.auto_ability = not self.auto_ability
                                    # force auto target off
                                    self.auto_target = False
                                    try:
                                        self.after(0, lambda: self.btn_ability.config(bg="#005500" if self.auto_ability else "#550000", text="Ability: ON" if self.auto_ability else "Ability"))
                                        self.after(0, lambda: self.btn_target.config(bg="#550000", text="Target"))
                                    except Exception:
                                        pass
                                # Pause targeting while key is down
                                self.pause_targeting = True
                                self._hook_last_state[vk] = True
                        elif wParam == WM_KEYUP or wParam == WM_SYSKEYUP:
                            # Key released
                            self._hook_last_state[vk] = False
                            # Only grave key (192 = 0xC0)
                            if vk == 192:
                                self.pause_targeting = False
                except Exception:
                    pass
                return user32.CallNextHookEx(self._hook_id if hasattr(self, '_hook_id') else None, nCode, wParam, lParam)

            # Save the callback to prevent GC
            self._keyboard_proc = low_level_keyboard_proc
            hMod = kernel32.GetModuleHandleW(None)
            # Install hook
            self._hook_id = user32.SetWindowsHookExW(WH_KEYBOARD_LL, self._keyboard_proc, hMod, 0)
            self.hook_installed = self._hook_id != 0
            # Message loop - required to keep the hook alive
            msg = wintypes.MSG()
            self._hook_thread_id = kernel32.GetCurrentThreadId()
            while True:
                bRet = user32.GetMessageW(ctypes.byref(msg), None, 0, 0)
                if bRet == 0:
                    break
                elif bRet == -1:
                    break
                else:
                    user32.TranslateMessage(ctypes.byref(msg))
                    user32.DispatchMessageW(ctypes.byref(msg))
            # Cleanup
            try:
                if hasattr(self, '_hook_id') and self._hook_id:
                    user32.UnhookWindowsHookEx(self._hook_id)
            except Exception:
                pass
            self.hook_installed = False
        except Exception:
            self.hook_installed = False

    def _uninstall_keyboard_hook(self):
        try:
            user32 = ctypes.windll.user32
            kernel32 = ctypes.windll.kernel32
            if hasattr(self, '_hook_id') and self._hook_id:
                user32.UnhookWindowsHookEx(self._hook_id)
            if hasattr(self, '_hook_thread_id') and self._hook_thread_id:
                user32.PostThreadMessageW(self._hook_thread_id, 0x0012, 0, 0)  # WM_QUIT
        except Exception:
            pass

    def _get_target_key(self, prio):
        action = None
        default = None
        if prio == 1: action, default = "TARGETSELF", "F1"
        elif prio == 2: action, default = "TARGETPARTYMEMBER1", "F2"
        elif prio == 3: action, default = "TARGETPARTYMEMBER2", "F3"
        elif prio == 4: action, default = "TARGETPARTYMEMBER3", "F4"
        elif prio == 5: action, default = "TARGETPARTYMEMBER4", "F5"
        elif prio == 10: action = "TARGETMOUSEOVER"
        elif prio == 255: action = "TARGETSCANENEMY"
        elif prio > 5: action, default = "TARGETNEARESTENEMY", "TAB"
        
        if not action: return None
        key = self.action_map.get(action, default)
        if not key: self._log_warning(f"{action} binding not set"); return None
        return key

    def _refresh_loop(self):
        delay = 100
        try:
            # Handle toggle key (grave/backtick) press for toggling ability and pause targeting
            try:
                # Reload toggle_vk from config in case it was updated
                self.toggle_vk = int(self.config_data.get('toggle_vk', 192) or 192)
                if self.toggle_vk:
                    cur_state = win32api.GetAsyncKeyState(self.toggle_vk) & 0x8000
                    # Rising edge - toggle ability
                    if cur_state and not self._toggle_last_state:
                        self.auto_ability = not self.auto_ability
                        # update UI
                        self.btn_ability.config(bg="#005500" if self.auto_ability else "#550000", text="Ability: ON" if self.auto_ability else "Ability")
                        # Ensure auto_target is disabled when toggling via refresh loop
                        self.auto_target = False
                        try:
                            self.btn_target.config(bg="#550000", text="Target")
                        except Exception:
                            pass
                    # Pause targeting while key is pressed
                    self.pause_targeting = bool(cur_state)
                    self._toggle_last_state = cur_state
            except Exception:
                # Fallback if win32api not available or other errors
                pass
            if self.current_pos:
                vals = scan.decode_5x5(self.current_pos, self.config_data["square_size"])
                valid = scan.validate_checksum(vals)
                
                # DEFAULTS if invalid
                slot = vals[1] if valid else 2
                prio = vals[2] if valid else 255

                # Status update
                if valid:
                    self.lbl_status.config(text=f"Running OK | S:{slot} P:{prio}", fg="#00ff00")
                    if self.insp_window and tk.Toplevel.winfo_exists(self.insp_window): self.insp_window.update_data(vals)
                else:
                    self.lbl_status.config(text=f"Lost/Invalid (Defaulting) | S:{slot} P:{prio}", fg="orange")
                    self._last_log_ability = ""; self._last_log_target = ""

                # --- EXECUTE (Runs on Defaults too) ---
                action_taken = False
                
                # Phase 0: Ability
                if self._cycle_phase == 0:
                    self._cycle_phase = 1
                    if self.auto_ability and slot > 0:
                        key = self.slot_map.get(slot)
                        if key: 
                            self._log_action("Ability", slot, key)
                            inp.send_key(key)
                            action_taken = True
                        else: self._log_warning(f"Slot {slot} binding not set")

                # Phase 1: Target
                elif self._cycle_phase == 1:
                    self._cycle_phase = 0
                    # Only run auto-targeting when not paused by toggle key
                    if self.auto_target and (not self.pause_targeting) and prio != 0:
                        tkey = self._get_target_key(prio)
                        if tkey: 
                            self._log_action("Target", prio, tkey)
                            if prio == 255: inp.send_key(tkey, duration=0.2)
                            else: inp.send_key(tkey)
                            action_taken = True
                
                if action_taken: delay = random.randint(200, 300)
                else: delay = 50
            else:
                self.lbl_status.config(text="Please Set Square Area", fg="#ff5555")
        except Exception as e: print(e)
        self.after(delay, self._refresh_loop)

if __name__ == "__main__":
    app = Overlay()
    app.mainloop()
import sys
import os
import time
import math
import random
import tkinter as tk
from tkinter import ttk, messagebox
from pathlib import Path

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
        icon_row = tk.Frame(dash, bg="#222"); icon_row.pack(fill="x", padx=5, pady=5)
        self.lbl_combat = tk.Label(icon_row, text="COMBAT", bg="#333", fg="#555", width=10, font=("Segoe UI", 9, "bold"), relief="raised"); self.lbl_combat.pack(side="left", padx=2)
        self.lbl_gold = tk.Label(icon_row, text="0g 0s", bg="#222", fg="#ffD700", font=("Consolas", 10)); self.lbl_gold.pack(side="right", padx=5)
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
        self.title("Options"); self.config(bg="#222"); self.attributes("-topmost", True); self.geometry("280x300"); self.parent = parent
        style = ttk.Style(); style.theme_use('clam'); style.configure("TLabel", background="#222", foreground="#eee")
        self._build_ui(); self._load_values()

    def _build_ui(self):
        pad = {'padx': 10, 'pady': 5}
        ttk.Label(self, text="Account:").pack(anchor="w", **pad)
        self.cb_account = ttk.Combobox(self, state="readonly"); self.cb_account.pack(fill="x", **pad)
        self.cb_account.bind("<<ComboboxSelected>>", self._on_account_change)
        ttk.Label(self, text="Character:").pack(anchor="w", **pad)
        self.cb_char = ttk.Combobox(self, state="readonly"); self.cb_char.pack(fill="x", **pad)
        self.cb_char.bind("<<ComboboxSelected>>", self._on_char_change)
        tk.Button(self, text="Reload Bindings", bg="#444", fg="white", command=self.parent._load_bindings).pack(fill="x", **pad)
        tk.Button(self, text="Set Square Area", bg="#0055aa", fg="white", command=self.parent._set_square).pack(fill="x", **pad)
        tk.Button(self, text="Close", bg="#552222", fg="white", command=self.destroy).pack(fill="x", pady=20, padx=10)

    def _load_values(self):
        root = self.parent.config_data.get("root_dir", "")
        accts = bind.get_accounts(root)
        self.cb_account["values"] = accts
        saved = self.parent.config_data.get("selected_account", "")
        if saved in accts: self.cb_account.set(saved); self._on_account_change(None, skip_save=True)

    def _on_account_change(self, event, skip_save=False):
        root = self.parent.config_data.get("root_dir", "")
        acct = self.cb_account.get()
        chars = bind.get_characters(root, acct)
        self.cb_char["values"] = chars
        saved = self.parent.config_data.get("selected_character", "")
        if saved in chars: self.cb_char.set(saved)
        elif chars: self.cb_char.current(0)
        else: self.cb_char.set("")
        if not skip_save:
            self.parent.config_data["selected_account"] = acct
            cfg.save(self.parent.config_data)
            self.parent._load_bindings()

    def _on_char_change(self, event):
        self.parent.config_data["selected_character"] = self.cb_char.get()
        cfg.save(self.parent.config_data)
        self.parent._load_bindings()

# --- MAIN OVERLAY ---
class Overlay(tk.Tk):
    def __init__(self):
        super().__init__()
        self.overrideredirect(True); self.attributes("-topmost", True, "-alpha", 0.85); self.config(bg="#111")
        self.config_data = cfg.load()
        self.geometry(f"320x220+{self.config_data.get('window_x', 50)}+{self.config_data.get('window_y', 50)}")
        self.current_pos = cfg.load_pos(); self.slot_map = {}; self.action_map = {}; self.auto_ability = False; self.auto_target = False
        self.opt_window = None; self.insp_window = None
        self.press_history = []; self.shown_warnings = set()
        self._last_log_ability = ""; self._last_log_target = ""
        self._drag_data = {"x": 0, "y": 0}
        
        # Cycle State: 0=Ability, 1=Target
        self._cycle_phase = 0
        
        self.bind("<ButtonPress-1>", self._start_move); self.bind("<B1-Motion>", self._do_move); self.bind("<ButtonRelease-1>", self._stop_move)
        self._build_overlay_ui(); self._load_bindings(); self.after(100, self._refresh_loop)

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

        row1 = tk.Frame(c, bg="#111"); row1.pack(side="bottom", fill="x", pady=(2,0))
        opts = {"side": "left", "fill": "x", "expand": True, "padx": 1}
        tk.Button(row1, text="Exit", bg="#442222", fg="white", command=self._quit_app).pack(**opts)
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

    def _quit_app(self): self.destroy(); sys.exit()
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
        self.txt_log.config(state="normal"); self.txt_log.insert("end", text + "\n", tag)
        if int(self.txt_log.index('end-1c').split('.')[0]) > 6: self.txt_log.delete("1.0", "2.0")
        self.txt_log.see("end"); self.txt_log.config(state="disabled")

    def _get_target_key(self, prio):
        action = None
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
                    if self.auto_target and prio != 0:
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
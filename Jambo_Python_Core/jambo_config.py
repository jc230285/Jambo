import json
from pathlib import Path

CONFIG_FILE = Path(__file__).parent / "square_config.json"
POS_FILE = Path(__file__).parent / "square_pos.json"

DEFAULT_CONFIG = {
    "square_size": 58,
    "cell_size": 10,
    "padding": 0,
    "root_dir": r"C:\Program Files (x86)\World of Warcraft\_classic_era_",
    "selected_account": "JC230285",
    "selected_character": "Spineshatter/Jambodru",
    "window_x": 5,
    "window_y": 582,
    "toggle_key": "`",
    "toggle_vk": 223,  # Your recorded key
    "pos": [4, 0]  # Default square position [row, col]
}

def load():
    cfg = DEFAULT_CONFIG.copy()
    if CONFIG_FILE.exists():
        try: cfg.update(json.loads(CONFIG_FILE.read_text()))
        except: pass
    return cfg

def save(cfg):
    CONFIG_FILE.write_text(json.dumps(cfg, indent=4))

def load_pos():
    if POS_FILE.exists():
        try: return tuple(json.loads(POS_FILE.read_text())["pos"])
        except: return None
    return None

def save_pos(pos):
    POS_FILE.write_text(json.dumps({"pos": pos}))
    return pos
#!/usr/bin/env python3
"""
Zygor import helper

- Parses Lists_Guides.lua into a Python structure.
- Pulls recipe/product/reagent/vendor data from the Zygor addon files.
- Normalises and dedupes vendor blocks.
- Writes a validated Lua file (or .preview when --dry-run is passed).
"""
import argparse
import glob
import os
import re
import sys
from collections import OrderedDict
from copy import deepcopy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LISTS_GUIDES = os.path.join(ROOT, "Lists_Guides.lua")
LISTS_GUIDES_PREVIEW = LISTS_GUIDES + ".preview"
LISTS_GUIDES_BAK = LISTS_GUIDES + ".bak"
ZYGOR_ROOT = os.path.abspath(os.path.join(ROOT, "..", "ZygorGuidesViewerClassic"))
ZYGOR_TRADES = os.path.join(ZYGOR_ROOT, "Data-Classic", "Tradeskill_Recipes.lua")
ZYGOR_GUIDES_DIR = os.path.join(ZYGOR_ROOT, "Guides-Classic", "Professions")
LIBROVER_DATA = os.path.join(ZYGOR_ROOT, "Libs-Classic", "LibRover-1.0", "data.lua")

# --------------------------------------------------------------------------------------
#  Minimal Lua parser/serializer (suited for our simple data files)
# --------------------------------------------------------------------------------------


class Token:
    def __init__(self, kind, value):
        self.kind = kind
        self.value = value

    def __repr__(self):
        return f"Token({self.kind!r}, {self.value!r})"


def _tokenise(s):
    """
    Tokenise a Lua-ish subset: numbers, strings, identifiers, braces, commas, equals.
    Strips line comments starting with --.
    """
    tokens = []
    pattern = re.compile(
        r"""\s*(?:
            (--.*$)                        # comment
            |([{}\[\]=,])                  # symbols
            |("(?:\\.|[^"\\])*")           # string
            |([A-Za-z_][\w]*)              # identifier
            |([+-]?\d+\.\d+|[+-]?\d+)      # number
        )""",
        re.MULTILINE | re.VERBOSE,
    )
    pos = 0
    for m in pattern.finditer(s):
        if m.start() != pos:
            gap = s[pos : m.start()].strip()
            if gap:
                raise ValueError(f"Unexpected content while tokenising near: {gap[:20]!r}")
        pos = m.end()
        if m.group(1):
            continue  # comment
        if m.group(2):
            tokens.append(Token("SYM", m.group(2)))
        elif m.group(3):
            tokens.append(Token("STRING", m.group(3)[1:-1].encode("utf-8").decode("unicode_escape")))
        elif m.group(4):
            tokens.append(Token("IDENT", m.group(4)))
        elif m.group(5):
            num = m.group(5)
            tokens.append(Token("NUMBER", float(num) if "." in num else int(num)))
    return tokens


class LuaParser:
    def __init__(self, text):
        self.tokens = _tokenise(text)
        self.idx = 0

    def _peek(self):
        return self.tokens[self.idx] if self.idx < len(self.tokens) else None

    def _accept(self, kind, value=None):
        tok = self._peek()
        if tok and tok.kind == kind and (value is None or tok.value == value):
            self.idx += 1
            return tok
        return None

    def _expect(self, kind, value=None):
        tok = self._accept(kind, value)
        if not tok:
            raise ValueError(f"Expected {kind} {value or ''} at token {self.idx}")
        return tok

    def parse(self):
        val = self._parse_value()
        return val

    def _parse_value(self):
        tok = self._peek()
        if not tok:
            raise ValueError("Unexpected end of input")
        if tok.kind == "SYM" and tok.value == "{":
            return self._parse_table()
        if tok.kind == "STRING":
            self.idx += 1
            return tok.value
        if tok.kind == "NUMBER":
            self.idx += 1
            return tok.value
        if tok.kind == "IDENT":
            self.idx += 1
            if tok.value == "true":
                return True
            if tok.value == "false":
                return False
            if tok.value == "nil":
                return None
            return tok.value
        raise ValueError(f"Unexpected token {tok}")

    def _parse_table(self):
        self._expect("SYM", "{")
        arr = []
        mapping = OrderedDict()
        has_keys = False
        while True:
            if self._accept("SYM", "}"):
                break
            if self._accept("SYM", "[" ):
                key = self._parse_value()
                self._expect("SYM", "]")
                self._expect("SYM", "=")
                val = self._parse_value()
                mapping[key] = val
                has_keys = True
            else:
                # either key=value or bare value
                tok = self._peek()
                nxt = self.tokens[self.idx + 1] if (self.idx + 1) < len(self.tokens) else None
                if tok and tok.kind in ("IDENT", "STRING") and nxt and nxt.kind == "SYM" and nxt.value == "=":
                    key = tok.value
                    self.idx += 2  # consume key and '='
                    val = self._parse_value()
                    mapping[key] = val
                    has_keys = True
                else:
                    val = self._parse_value()
                    arr.append(val)
            self._accept("SYM", ",")
        if has_keys and not arr:
            return mapping
        if not has_keys:
            return arr
        # mixed table: keep array items with numeric indices to preserve data
        for idx, val in enumerate(arr, 1):
            mapping.setdefault(idx, val)
        return mapping


def _is_identifier(s):
    return isinstance(s, str) and re.fullmatch(r"[A-Za-z_][\w]*", s)


def _lua_escape(s):
    return s.replace("\\", "\\\\").replace('"', r"\"")


def _lua_key(k):
    if isinstance(k, int):
        return f"[{k}]"
    if _is_identifier(k):
        return k
    return f'["{_lua_escape(str(k))}"]'


STEP_KEY_ORDER = [
    "min",
    "max",
    "type",
    "text",
    "recipeName",
    "recipeItem",
    "item",
    "reagents",
    "altReagents",
    "tools",
    "station",
    "targetSkill",
    "target",
    "zone",
    "vendors",
]


def _lua_format(value, indent=0, inline=False):
    pad = " " * indent
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "nil"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return str(value)
    if isinstance(value, str):
        return f'"{_lua_escape(value)}"'
    if isinstance(value, list):
        parts = [_lua_format(v, indent + 4, True) for v in value]
        if inline or (parts and max(len(p) for p in parts) < 50):
            return "{ " + ", ".join(parts) + " }"
        lines = ["{"] + [pad + "    " + p + "," for p in parts] + [pad + "}"]
        return "\n".join(lines)
    if isinstance(value, dict):
        keys = STEP_KEY_ORDER + [k for k in value.keys() if k not in STEP_KEY_ORDER]
        pieces = []
        for k in keys:
            if k not in value:
                continue
            pieces.append(f"{_lua_key(k)}={_lua_format(value[k], indent + 4, True)}")
        single_line = "{ " + ", ".join(pieces) + " }"
        if inline or len(single_line) <= 120:
            return single_line
        lines = ["{"] + [pad + "    " + p + "," for p in pieces] + [pad + "}"]
        return "\n".join(lines)
    raise TypeError(f"Unsupported type for Lua formatting: {type(value)}")


def lua_dump_table(obj, indent=0):
    pad = " " * indent
    if not isinstance(obj, dict):
        return _lua_format(obj, indent)
    lines = ["{"]
    for idx, (k, v) in enumerate(obj.items()):
        key = _lua_key(k)
        lines.append(f'{pad}    {key} = {{')
        if isinstance(v, list):
            for step in v:
                lines.append(f"{pad}        {_lua_format(step, indent + 8, True)},")
        else:
            lines.append(f"{pad}        {_lua_format(v, indent + 8, True)},")
        lines.append(f"{pad}    }}{',' if idx < len(obj)-1 else ''}")
    lines.append(pad + "}")
    return "\n".join(lines)

# --------------------------------------------------------------------------------------
#  Data helpers
# --------------------------------------------------------------------------------------


def read_file(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        return f.read()


def extract_guidedata():
    text = read_file(LISTS_GUIDES)
    m = re.search(r"ns\.guideData\s*=\s*{", text)
    if not m:
        raise RuntimeError("ns.guideData block not found")
    start = m.start()
    brace_level = 0
    end = None
    for idx in range(start, len(text)):
        ch = text[idx]
        if ch == "{":
            brace_level += 1
        elif ch == "}":
            brace_level -= 1
            if brace_level == 0:
                end = idx
                break
    if end is None:
        raise RuntimeError("Unbalanced braces in Lists_Guides.lua")
    table_text = text[m.end() - 1 : end + 1]
    parsed = LuaParser(table_text).parse()
    return parsed, text[: start], text[end + 1 :]


def load_recipe_map():
    rec_text = read_file(ZYGOR_TRADES)
    recipe_map = {}
    for match in re.finditer(r"\[\s*(\d+)\s*]\s*=\s*{", rec_text):
        start = match.end() - 1
        depth = 0
        end = None
        for idx in range(start, len(rec_text)):
            ch = rec_text[idx]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    end = idx
                    break
        if end is None:
            continue
        block = rec_text[start : end + 1]
        name_m = re.search(r'\["name"\]\s*=\s*"([^"]+)"', block)
        if not name_m:
            continue
        name = name_m.group(1)
        prod = re.search(r'\["productid"\]\s*=\s*(\d+)', block)
        productid = int(prod.group(1)) if prod else None
        reagents = {}
        for rmatch in re.finditer(r'\{\s*\["num"\]\s*=\s*(\d+),\s*\["id"\]\s*=\s*(\d+)', block):
            reagents[int(rmatch.group(2))] = int(rmatch.group(1))
        learned = re.search(r'\["learnedat"\]\s*=\s*"?(\d+)"?', block)
        learned_at = int(learned.group(1)) if learned else None
        recipe_map[name] = {"productid": productid, "reagents": reagents, "learnedat": learned_at}
    return recipe_map


def load_buy_map():
    buy_map = {}
    pattern_inline = re.compile(r"buy Recipe: ([^#\n]+)##(\d+)(?:\s*\|goto\s*([^\n]*?)\s*(\d+\.\d+),(\d+\.\d+))?")
    for gfile in glob.glob(os.path.join(os.path.dirname(ZYGOR_GUIDES_DIR), "**", "*.lua"), recursive=True):
        text = read_file(gfile)
        for m in pattern_inline.finditer(text):
            rname = m.group(1).strip()
            rid = int(m.group(2))
            zone = m.group(3).strip() if m.group(3) else None
            x = float(m.group(4)) if m.group(4) else None
            y = float(m.group(5)) if m.group(5) else None
            buy_map[rname] = {"rid": rid, "zone": zone, "x": x, "y": y}
        lines = text.splitlines()
        for i, line in enumerate(lines):
            if "buy Recipe:" not in line:
                continue
            m = re.search(r"buy Recipe: ([^#\n]+)##(\d+)", line)
            if not m:
                continue
            rname = m.group(1).strip()
            rid = int(m.group(2))
            zone = None
            x = None
            y = None
            for k in range(i, min(i + 5, len(lines))):
                if "goto" in lines[k]:
                    mg = re.search(r"goto\s*([A-Za-z'\"\\s/%-]+)\s*(\d+\.\d+),(\d+\.\d+)", lines[k])
                    if mg:
                        zone = mg.group(1).strip()
                        x = float(mg.group(2))
                        y = float(mg.group(3))
                        break
            buy_map[rname] = {"rid": rid, "zone": zone, "x": x, "y": y}
    return buy_map


def load_mapids():
    data = read_file(LIBROVER_DATA)
    mapids = {}
    for m in re.finditer(r'\["(?P<name>[^"]+)"\]\s*=\s*{\s*\[0\]\s*=\s*(?P<id>\d+)', data):
        mapids[m.group("name")] = int(m.group("id"))
    return mapids


def dedupe_vendors(vendors, mapids):
    cleaned = []
    seen = set()
    for v in vendors:
        v = {k: v[k] for k in v}  # ensure plain dict
        if "zone" in v and "mapID" not in v:
            zkey = v["zone"].split("/")[0].strip()
            if zkey in mapids:
                v["mapID"] = mapids[zkey]
        key = (
            v.get("npc"),
            v.get("name"),
            v.get("zone"),
            round(v.get("x", 0), 4) if isinstance(v.get("x"), (int, float)) else v.get("x"),
            round(v.get("y", 0), 4) if isinstance(v.get("y"), (int, float)) else v.get("y"),
            v.get("faction"),
        )
        if key in seen:
            continue
        seen.add(key)
        cleaned.append(v)
    # Sort for deterministic output
    cleaned.sort(key=lambda v: (v.get("zone", ""), v.get("name", ""), v.get("npc", 0)))
    return cleaned


def ensure_list(val):
    if val is None:
        return []
    return val if isinstance(val, list) else [val]


def normalise_guides(guides, recipe_map, buy_map, mapids):
    guides = deepcopy(guides)
    for prof, steps in guides.items():
        if not isinstance(steps, list):
            continue
        for step in steps:
            if not isinstance(step, dict):
                continue
            if step.get("type") == "RECIPE" and step.get("recipeName"):
                zinfo = recipe_map.get(step["recipeName"])
                binfo = buy_map.get(step["recipeName"])
                if zinfo:
                    if "item" not in step and zinfo.get("productid"):
                        step["item"] = zinfo["productid"]
                    if "reagents" not in step and zinfo.get("reagents"):
                        step["reagents"] = zinfo["reagents"]
                    if "targetSkill" not in step and zinfo.get("learnedat"):
                        step["targetSkill"] = zinfo["learnedat"]
                if "targetSkill" not in step and "max" in step:
                    step["targetSkill"] = step["max"]
                if binfo:
                    if "recipeItem" not in step and binfo.get("rid"):
                        step["recipeItem"] = binfo["rid"]
                    if binfo.get("zone") or (binfo.get("x") is not None and binfo.get("y") is not None):
                        vendor_entry = {
                            "zone": binfo.get("zone"),
                            "mapID": mapids.get((binfo.get("zone") or "").split("/")[0].strip()),
                            "x": binfo.get("x"),
                            "y": binfo.get("y"),
                        }
                        step.setdefault("vendors", [])
                        step["vendors"].append({k: v for k, v in vendor_entry.items() if v is not None})
            if "vendors" in step:
                step["vendors"] = dedupe_vendors(ensure_list(step["vendors"]), mapids)
    return guides


def write_guides(guides, prefix, suffix, dry_run=False):
    lua_body = lua_dump_table(guides)
    output = f"{prefix}ns.guideData = {lua_body}\n{suffix}"
    out_path = LISTS_GUIDES_PREVIEW if dry_run else LISTS_GUIDES
    if not dry_run:
        with open(LISTS_GUIDES_BAK, "w", encoding="utf-8") as f:
            f.write(read_file(LISTS_GUIDES))
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(output)
    return out_path


def validate_roundtrip(guides):
    lua_text = lua_dump_table(guides)
    parsed = LuaParser(lua_text).parse()
    if not isinstance(parsed, dict) or not parsed:
        raise RuntimeError("Round-trip parse failed; result is empty or not a table")


def main():
    parser = argparse.ArgumentParser(description="Refresh Lists_Guides.lua from Zygor data")
    parser.add_argument("--dry-run", action="store_true", help="Write output to Lists_Guides.lua.preview only")
    args = parser.parse_args()

    guides, prefix, suffix = extract_guidedata()
    recipe_map = load_recipe_map()
    buy_map = load_buy_map()
    mapids = load_mapids()
    enriched = normalise_guides(guides, recipe_map, buy_map, mapids)
    validate_roundtrip(enriched)
    out_path = write_guides(enriched, prefix, suffix, dry_run=args.dry_run)
    mode = "preview" if args.dry_run else "updated"
    print(f"{mode} written to {out_path}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        sys.exit(1)

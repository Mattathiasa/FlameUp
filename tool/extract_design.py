#!/usr/bin/env python3
"""Decode the Claude Design prototype bundle into a readable design handoff.

The prototype ships as a single self-contained HTML file: the real sources live
gzipped + base64'd inside a <script type="__bundler/manifest"> block, and the
screen markup lives in a JSON-encoded <script type="__bundler/template"> block.

This script recovers all of it and writes design/extracted/:
    tokens.json          dark + light CSS variable maps, accent, blur, keyframes
    strings.json         every English/Amharic copy pair (K, K2, K3, K4)
    seed.json            dishes, ingredients, steps, regions, quests, ... 
    screens/<id>.html    the 30 per-screen markup blocks, one file each

Usage:  python3 tool/extract_design.py
"""

import base64
import gzip
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUNDLE = os.path.join(ROOT, "design", "FlameUp Prototype.html")
OUT = os.path.join(ROOT, "design", "extracted")


# --------------------------------------------------------------------------
# Bundle unpacking
# --------------------------------------------------------------------------

def read_bundle():
    with open(BUNDLE, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def bundler_block(src, tag):
    m = re.search(r'<script type="__bundler/%s"[^>]*>(.*?)</script>' % tag, src, re.S)
    if not m:
        raise SystemExit("bundle is missing the __bundler/%s block" % tag)
    return m.group(1)


def sources(src):
    """Decompress every text source in the manifest, keyed by mime type."""
    manifest = json.loads(bundler_block(src, "manifest"))
    out = {}
    for uuid, entry in manifest.items():
        if not entry["mime"].startswith("text/"):
            continue
        data = base64.b64decode(entry["data"])
        if entry.get("compressed"):
            data = gzip.decompress(data)
        out[uuid] = (entry["mime"], data.decode("utf-8", errors="replace"))
    return out


def dc_script(template):
    """The design's own logic: the <script type="text/x-dc"> body."""
    i = template.find("data-dc-script")
    if i == -1:
        raise SystemExit("template is missing the data-dc-script block")
    j = template.index(">", template.index("data-props", i))
    return template[j + 1: template.rindex("</script>")]


# --------------------------------------------------------------------------
# A small tolerant parser for the JS object/array literals in the dc-script.
# They use single quotes, bare keys and \u escapes, so json.loads cannot read
# them directly.
# --------------------------------------------------------------------------

class JsLiteral:
    def __init__(self, text, pos=0):
        self.s = text
        self.i = pos

    def ws(self):
        while self.i < len(self.s):
            c = self.s[self.i]
            if c in " \t\r\n":
                self.i += 1
            elif self.s.startswith("//", self.i):
                self.i = self.s.find("\n", self.i) + 1 or len(self.s)
            else:
                break

    def value(self):
        self.ws()
        c = self.s[self.i]
        if c == "{":
            return self.obj()
        if c == "[":
            return self.arr()
        if c in "'\"":
            return self.string()
        return self.atom()

    def obj(self):
        self.i += 1  # {
        out = {}
        while True:
            self.ws()
            if self.s[self.i] == "}":
                self.i += 1
                return out
            key = self.string() if self.s[self.i] in "'\"" else self.ident()
            self.ws()
            assert self.s[self.i] == ":", "expected ':' at %d" % self.i
            self.i += 1
            out[key] = self.value()
            self.ws()
            if self.s[self.i] == ",":
                self.i += 1

    def arr(self):
        self.i += 1  # [
        out = []
        while True:
            self.ws()
            if self.s[self.i] == "]":
                self.i += 1
                return out
            out.append(self.value())
            self.ws()
            if self.s[self.i] == ",":
                self.i += 1

    def string(self):
        quote = self.s[self.i]
        self.i += 1
        buf = []
        while self.s[self.i] != quote:
            c = self.s[self.i]
            if c == "\\":
                nxt = self.s[self.i + 1]
                if nxt == "u":
                    buf.append(chr(int(self.s[self.i + 2: self.i + 6], 16)))
                    self.i += 6
                    continue
                buf.append({"n": "\n", "t": "\t", "r": "\r"}.get(nxt, nxt))
                self.i += 2
                continue
            buf.append(c)
            self.i += 1
        self.i += 1
        return "".join(buf)

    def ident(self):
        start = self.i
        while self.s[self.i].isalnum() or self.s[self.i] in "_$":
            self.i += 1
        return self.s[start:self.i]

    def atom(self):
        start = self.i
        while self.s[self.i] not in ",}]\n":
            self.i += 1
        raw = self.s[start:self.i].strip()
        if raw in ("true", "false"):
            return raw == "true"
        if raw == "null":
            return None
        try:
            return int(raw)
        except ValueError:
            pass
        try:
            return float(raw)
        except ValueError:
            return raw


def const(script, name):
    """Parse `const NAME = <literal>` out of the dc-script."""
    m = re.search(r"\bconst\s+%s\s*=\s*" % re.escape(name), script)
    if not m:
        raise SystemExit("dc-script has no const named %s" % name)
    return JsLiteral(script, m.end()).value()


# --------------------------------------------------------------------------
# Screen splitting
# --------------------------------------------------------------------------

def split_screens(template):
    """Carve the 30 `<sc-if value="{{ s.<id> }}">` blocks out of the template.

    sc-if nests, so we balance opens against closes rather than taking the
    first `</sc-if>` we meet.
    """
    lines = template.split("\n")
    starts = []
    for n, line in enumerate(lines):
        m = re.search(r'sc-if value="\{\{ s\.(\w+) \}\}"', line)
        if m:
            starts.append((m.group(1), n))

    screens = {}
    for screen_id, start in starts:
        depth = 0
        for n in range(start, len(lines)):
            depth += len(re.findall(r"<sc-if\b", lines[n]))
            depth -= len(re.findall(r"</sc-if>", lines[n]))
            if depth == 0:
                screens[screen_id] = "\n".join(lines[start:n + 1])
                break
        else:
            raise SystemExit("unbalanced sc-if for screen %s" % screen_id)
    return screens


# --------------------------------------------------------------------------

def write(path, payload):
    full = os.path.join(OUT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as fh:
        if isinstance(payload, str):
            fh.write(payload)
        else:
            json.dump(payload, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
    return full


def pairs(*maps):
    """Flatten the K/K2/K3/K4 [english, amharic] maps into one dict."""
    out = {}
    for m in maps:
        for key, value in m.items():
            out[key] = {"en": value[0], "am": value[1]}
    return out


def main():
    src = read_bundle()
    template = json.loads(bundler_block(src, "template"))
    script = dc_script(template)

    # --- design tokens -----------------------------------------------------
    props = re.search(r'data-props="([^"]*)"', template).group(1)
    props = json.loads(props.replace("&quot;", '"'))
    style = re.search(r"<style>\s*(html,body\{.*?)</style>", template, re.S).group(1)
    tokens = {
        "accent": props["accent"]["default"],
        "accentOptions": props["accent"]["options"],
        "blurPx": props["glass"]["default"],
        "dark": const(script, "DARK"),
        "light": const(script, "LIGHT"),
        "keyframes": dict(re.findall(r"@keyframes\s+([\w-]+)\s*\{(.*?)\}\s*\n", style, re.S)),
        "baseFontStack": "-apple-system, \"SF Pro Text\", system-ui, \"Noto Sans Ethiopic\", sans-serif",
    }
    write("tokens.json", tokens)

    # --- copy --------------------------------------------------------------
    strings = pairs(*(const(script, n) for n in ("K", "K2", "K3", "K4")))
    write("strings.json", strings)

    # --- structural + seed data -------------------------------------------
    groups = const(script, "SC")
    seed = {
        "screenGroups": [
            {
                "en": g[0],
                "am": g[1],
                "screens": [{"id": s[0], "en": s[1], "am": s[2]} for s in g[2]],
            }
            for g in groups
        ],
        "tabs": [{"screen": t[0], "labelKey": t[1], "iconPath": t[2]}
                 for t in const(script, "TABS")],
        "screensWithoutTabs": sorted(const(script, "NOTABS").keys()),
        "dishes": const(script, "D"),
        "doroWatIngredients": [
            {"en": r[0], "am": r[1], "qtyEn": r[2], "qtyAm": r[3]}
            for r in const(script, "ING")
        ],
        "doroWatSteps": [{"en": r[0], "am": r[1]} for r in const(script, "STEPS")],
        "mastery": [
            {"en": r[0], "am": r[1], "percent": r[2], "color": r[3], "tier": r[4]}
            for r in const(script, "MAST")
        ],
        "achievements": [
            {"en": r[0], "am": r[1], "earned": bool(r[2]), "color": r[3]}
            for r in const(script, "ACHV")
        ],
        "quests": [
            {"groupKey": r[0], "en": r[1], "am": r[2],
             "progress": r[3], "goal": r[4], "xp": r[5], "color": r[6]}
            for r in const(script, "QUESTS")
        ],
        "regions": [
            {"en": r[0], "am": r[1], "exploredPercent": r[2], "colorA": r[3], "colorB": r[4]}
            for r in const(script, "REGS")
        ],
        "elders": [
            {"nameEn": r[0], "nameAm": r[1], "placeEn": r[2], "placeAm": r[3],
             "topicEn": r[4], "topicAm": r[5], "length": r[6],
             "colorA": r[7], "colorB": r[8]}
            for r in const(script, "ELDERS")
        ],
        "feed": [
            {"whoEn": r[0], "whoAm": r[1], "dishEn": r[2], "dishAm": r[3],
             "bodyEn": r[4], "bodyAm": r[5], "ago": r[6], "likes": r[7],
             "dishColorA": r[8], "dishColorB": r[9], "avatarColor": r[10]}
            for r in const(script, "FEED")
        ],
        "friends": [
            {"en": r[0], "am": r[1], "streak": r[2], "added": bool(r[3]), "avatarColor": r[4]}
            for r in const(script, "FRIENDS")
        ],
        "leaderboard": [
            {"en": r[0], "am": r[1], "xp": r[2], "avatarColor": r[3]}
            for r in const(script, "LB")
        ],
        "shoppingList": [
            {"aisleKey": r[0], "en": r[1], "am": r[2], "qtyEn": r[3], "qtyAm": r[4]}
            for r in const(script, "SHOP")
        ],
        "mealPlan": [
            {"en": r[0], "am": r[1], "dish": r[2] or None}
            for r in const(script, "PLAN")
        ],
    }
    write("seed.json", seed)

    # --- per-screen markup -------------------------------------------------
    screens = split_screens(template)
    order = [s["id"] for g in seed["screenGroups"] for s in g["screens"]]
    missing = [i for i in order if i not in screens]
    if missing:
        raise SystemExit("could not carve out screens: %s" % ", ".join(missing))
    for n, screen_id in enumerate(order, 1):
        write("screens/%02d-%s.html" % (n, screen_id), screens[screen_id])

    print("tokens.json    %d dark vars, %d light vars, %d keyframes"
          % (len(tokens["dark"]), len(tokens["light"]), len(tokens["keyframes"])))
    print("strings.json   %d English/Amharic pairs" % len(strings))
    print("seed.json      %d dishes, %d regions, %d achievements, %d quests, %d elders"
          % (len(seed["dishes"]), len(seed["regions"]),
             len(seed["achievements"]), len(seed["quests"]), len(seed["elders"])))
    print("screens/       %d screen files" % len(order))


if __name__ == "__main__":
    sys.exit(main())

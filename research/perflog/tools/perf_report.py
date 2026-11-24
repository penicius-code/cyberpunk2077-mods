r"""Cyberslop PerfLog report (2026-11-22). Turns one launch's CyberslopPerfLog CSV + log growth into a ranked report.

usage:
  perf_report.py                  report for the newest perf-*.csv (writes reports\<csv name>.md and prints it)
  perf_report.py <perf csv>       report for that file
  perf_report.py --snapshot       record the size of every mod/plugin log (run it before each game start)
  perf_report.py --list           list the perf logs with duration and hitch rate

What it answers:
  * when / where / doing what the game hitched (per context: on foot, vehicle, combat, menu), worst windows,
    hitch hot spots by 100 m map cell;
  * how many hitches coincided with a Lua GC cycle start (CET heap problem -> CET mods) vs not (engine, redscript,
    native plugins, GPU, streaming);
  * Lua heap floor and its growth per hour (a mod building caches), allocation rate;
  * which mods wrote the most log bytes and the most CET errors during that launch (snapshot before the start
    vs now; a mod spamming errors or logs every frame is itself heavy).
Per-CET-mod CPU time cannot be measured from inside CET (no debug/jit library in its sandbox); for a suspect,
use targeted tools: an ETW capture such as HitchWatch (native plugins + CET as a block) and
a Lua heap marker per CET mod.
"""
import collections
import csv
import datetime
import glob
import json
import os
import re
import sys

GAME = os.environ.get("CP2077_GAME_DIR", os.getcwd())  # game folder: set CP2077_GAME_DIR or run from it
CET = os.path.join(GAME, r"bin\x64\plugins\cyber_engine_tweaks")
MODS = os.path.join(CET, "mods")
PERF_DIR = os.path.join(MODS, "CyberslopPerfLog")
HERE = os.path.dirname(os.path.abspath(__file__))
SNAP_DIR = os.path.join(HERE, "snapshots")
REPORT_DIR = os.path.join(HERE, "reports")
KEEP_SNAPS = 40

W_COLS = ["t", "time", "uptime", "foot", "veh", "combat", "menu", "pre", "frames", "fps", "p50", "p95", "p99",
          "worst", "hitches", "hitch_ms", "gc", "gc_hitches", "gc_hitch_ms", "heap_min", "heap_end", "alloc_kbs",
          "x", "y", "stalls"]


def log_files():
    pats = [os.path.join(MODS, "*", "*.log"), os.path.join(CET, "*.log"), os.path.join(GAME, r"red4ext\logs\*.log"),
            os.path.join(GAME, r"red4ext\plugins\*\*.log"), os.path.join(GAME, r"red4ext\plugins\*\logs\*.log"),
            os.path.join(GAME, r"r6\logs\*.log")]
    out = {}
    for p in pats:
        for f in glob.glob(p):
            try:
                st = os.stat(f)
                out[f] = [st.st_size, st.st_mtime]
            except OSError:
                pass
    return out


def snapshot():
    os.makedirs(SNAP_DIR, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    path = os.path.join(SNAP_DIR, f"prelaunch-{stamp}.json")
    data = {"time": stamp, "files": log_files()}
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f)
    os.replace(tmp, path)
    snaps = sorted(glob.glob(os.path.join(SNAP_DIR, "prelaunch-*.json")))
    for old in snaps[:-KEEP_SNAPS]:
        try:
            os.remove(old)
        except OSError:
            pass
    return f"log snapshot: {len(data['files'])} files"


def parse(path):
    W, H, S, I = [], [], [], []
    with open(path, encoding="utf-8", errors="replace") as f:
        for row in csv.reader(f):
            if not row or row[0].startswith("#"):
                continue
            k = row[0]
            try:
                if k == "W" and len(row) >= len(W_COLS):
                    d = dict(zip(W_COLS, row))
                    for c in W_COLS[2:]:
                        d[c] = float(d[c])
                    W.append(d)
                elif k == "H" and len(row) >= 9:
                    H.append({"time": row[1], "uptime": float(row[2]), "ms": float(row[3]), "ctx": row[4],
                              "gc": row[5] == "1", "heap": float(row[6]), "x": float(row[7]), "y": float(row[8])})
                elif k == "S" and len(row) >= 7:
                    S.append({"time": row[1], "uptime": float(row[2]), "old": row[3], "new": row[4]})
                elif k == "I":
                    I.append(row)
            except ValueError:
                continue
    return W, H, S, I


def csv_start(path):
    m = re.search(r"perf-(\d{8}-\d{6})\.csv$", path)
    return datetime.datetime.strptime(m.group(1), "%Y%m%d-%H%M%S") if m else None


def pick_snapshot(start):
    best = None
    for p in sorted(glob.glob(os.path.join(SNAP_DIR, "prelaunch-*.json"))):
        t = datetime.datetime.strptime(os.path.basename(p)[10:25], "%Y%m%d-%H%M%S")
        if start is None or t <= start + datetime.timedelta(minutes=2):
            best = p
    return best


def mod_of(path):
    rel = os.path.relpath(path, GAME)
    parts = rel.split(os.sep)
    if len(parts) > 6 and parts[4] == "mods":
        return "CET " + parts[5]
    if parts[0] == "red4ext" and len(parts) > 2 and parts[1] == "plugins":
        return "RED4ext " + parts[2]
    return rel


def log_growth(snap_path):
    if not snap_path:
        return [], None
    with open(snap_path, encoding="utf-8") as f:
        snap = json.load(f)["files"]
    rows = []
    for path, (size, _mt) in log_files().items():
        old = snap.get(path, [0, 0])[0]
        grew = size - old if size >= old else size   # rotated / truncated: count the new file
        if grew > 0:
            rows.append((grew, mod_of(path), path))
    rows.sort(reverse=True)
    return rows, snap


def cet_errors(snap):
    path = os.path.join(CET, "scripting.log")
    if not os.path.exists(path):
        return []
    start = snap.get(path, [0, 0])[0] if snap else 0
    size = os.path.getsize(path)
    if size < start:
        start = 0
    with open(path, "rb") as f:
        f.seek(start)
        text = f.read().decode("utf-8", errors="replace")
    count = collections.Counter()
    for line in text.splitlines():
        low = line.lower()
        if "error" not in low and "stack traceback" not in low and "attempt to" not in low:
            continue
        m = re.search(r"mods[\\/]([^\\/:]+)[\\/]", line)
        name = m.group(1) if m else None
        if not name:  # "[time] [thread] [mod] text": first bracket with a letter that is not the timestamp
            for b in re.findall(r"\[([^\]]+)\]", line):
                if re.search(r"[A-Za-z]", b) and "UTC" not in b:
                    name = b
                    break
        count[name or "?"] += 1
    return count.most_common(15)


def fmt_min(s):
    return f"{s / 60:.1f}"


def report(path):
    W, H, S, I = parse(path)
    start = csv_start(path)
    lines = [f"# PerfLog report: {os.path.basename(path)}", ""]
    if not W:
        lines.append("No complete 30 s window in this log yet.")
        return "\n".join(lines)
    total = W[-1]["uptime"]
    ctx_secs = {c: sum(w[c] for w in W) for c in ("foot", "veh", "combat", "menu", "pre")}
    play = sum(ctx_secs[c] for c in ("foot", "veh", "combat"))
    frames = sum(w["frames"] for w in W)
    # play windows only; 1.0.0 took the hitch baseline from the previous window's median, so a window right after a
    # loading screen (5 ms frames) counted every normal frame as a hitch: skip windows that follow a pre/menu window
    steady = [w for i, w in enumerate(W) if w["menu"] + w["pre"] < 5 and (i == 0 or W[i - 1]["menu"] + W[i - 1]["pre"] < 15)]
    steady_secs = sum(w["foot"] + w["veh"] + w["combat"] for w in steady)
    hitches = sum(w["hitches"] for w in steady)
    gc_h = sum(w["gc_hitches"] for w in steady)
    t_start = next((float(r[2]) for r in I if len(r) > 3 and "session start" in r[3]), 0.0)
    settled = [h for h in H if h["ctx"] in ("foot", "veh", "combat") and h["uptime"] > t_start + 90]
    settled_min = max((total - t_start - 90) / 60, 0.01)
    lines += [f"Launch {start} | uptime {fmt_min(total)} min | in play {fmt_min(play)} min | "
              f"menu {fmt_min(ctx_secs['menu'])} min | loading/pre {fmt_min(ctx_secs['pre'])} min", ""]
    fps_play = [w["fps"] for w in W if w["menu"] + w["pre"] < 5]
    med = sorted(fps_play)[len(fps_play) // 2] if fps_play else 0
    lines += ["## Overall", "",
              f"- median window fps (play): {med:.0f}; frames {int(frames)}; loading stalls > 1 s: {int(sum(w['stalls'] for w in W))}",
              f"- hitches in steady play (>= 2.5x typical frame and +18 ms): {int(hitches)} = {hitches / max(steady_secs / 60, 0.01):.1f}/min;"
              f" coinciding with a Lua GC cycle start: {int(gc_h)} ({100 * gc_h / max(hitches, 1):.0f} %)",
              f"- settled play (from 90 s after the load): {len(settled)} hitches >= 50 ms = {len(settled) / settled_min:.1f}/min,"
              f" {sum(h['gc'] for h in settled)} with GC, worst {max((h['ms'] for h in settled), default=0):.0f} ms",
              f"- worst frame: {max(w['worst'] for w in W):.0f} ms", ""]

    # per context from H lines (>= 50 ms) and context seconds
    lines += ["## Hitches >= 50 ms by what V was doing", "", "| context | minutes | hitches | per min | worst ms | GC share |",
              "|---|---|---|---|---|---|"]
    byc = collections.defaultdict(list)
    for h in H:
        byc[h["ctx"]].append(h)
    for c in ("foot", "veh", "combat", "menu", "pre"):
        hs = byc.get(c, [])
        mins = ctx_secs[c] / 60
        if mins < 0.2 and not hs:
            continue
        lines.append(f"| {c} | {mins:.1f} | {len(hs)} | {len(hs) / max(mins, 0.01):.1f} | "
                     f"{max((h['ms'] for h in hs), default=0):.0f} | {100 * sum(h['gc'] for h in hs) / max(len(hs), 1):.0f} % |")
    lines.append("")

    # heap
    play_w = [w for w in W if w["pre"] < 5]
    if len(play_w) >= 2:
        h0, h1 = play_w[0]["heap_min"], play_w[-1]["heap_min"]
        hours = max((play_w[-1]["uptime"] - play_w[0]["uptime"]) / 3600, 0.01)
        gcs = sum(w["gc"] for w in play_w)
        lines += ["## CET Lua heap", "",
                  f"- live-heap floor: {h0:.0f} MB -> {h1:.0f} MB ({(h1 - h0) / hours:+.0f} MB/h); max {max(w['heap_end'] for w in play_w):.0f} MB",
                  f"- GC cycles: {gcs / max((play_w[-1]['uptime'] - play_w[0]['uptime']) / 60, 0.01):.1f}/min; "
                  f"allocation ~{sum(w['alloc_kbs'] for w in play_w) / len(play_w):.0f} KB/s (lower bound)",
                  "- reference (2026-11-09/13): ~70 MB smooth, 70-110 MB sparse GC hitches, 140+ MB hitch every few s", ""]

    # worst windows
    worst = sorted(W, key=lambda w: (w["hitches"], w["worst"]), reverse=True)[:10]
    lines += ["## Worst 30 s windows", "", "| time | doing | hitches | GC | worst ms | fps | heap MB | x, y |",
              "|---|---|---|---|---|---|---|---|"]
    for w in worst:
        doing = max(("foot", "veh", "combat", "menu", "pre"), key=lambda c: w[c])
        lines.append(f"| {w['time'][11:]} | {doing} | {int(w['hitches'])} | {int(w['gc_hitches'])} | {w['worst']:.0f} | "
                     f"{w['fps']:.0f} | {w['heap_end']:.0f} | {w['x']:.0f}, {w['y']:.0f} |")
    lines.append("")

    # hot spots
    cells = collections.Counter((round(h["x"] / 100) * 100, round(h["y"] / 100) * 100) for h in H if h["ctx"] in ("foot", "veh", "combat"))
    if cells:
        lines += ["## Hitch hot spots (100 m cells, hitches >= 50 ms in play)", ""]
        for (x, y), n in cells.most_common(8):
            lines.append(f"- {x:.0f}, {y:.0f}: {n}")
        lines.append("")

    # logs
    snap_path = pick_snapshot(start)
    growth, snap = log_growth(snap_path)
    lines += ["## Log output during this launch (snapshot " + (os.path.basename(snap_path) if snap_path else "MISSING: run --snapshot before the game start") + ")", ""]
    if growth:
        lines += ["| bytes | source | file |", "|---|---|---|"]
        for grew, mod, p in growth[:15]:
            lines.append(f"| {grew:,} | {mod} | {os.path.basename(p)} |")
        lines.append("")
    errs = cet_errors(snap)
    if errs:
        lines += ["CET scripting.log error lines by mod (this launch): " + ", ".join(f"{m} {n}" for m, n in errs), ""]

    # hints
    lines += ["## Reading it", ""]
    if hitches and gc_h / hitches >= 0.5:
        lines.append("- Most hitches start with a Lua GC cycle: the CET side is the cause. Next: heap_markers.py to rank CET mods by heap, or patch the mods that log / error most above.")
    elif hitches:
        lines.append("- Most hitches are NOT Lua GC: look at engine / redscript / native plugins / streaming. Next: HitchWatch capture in the worst context above.")
    lines.append("- Contexts with a high per-minute rate point at the mods active there (vehicle mods, combat/AI mods, UI mods in menus).")
    return "\n".join(lines) + "\n"


def list_logs():
    for p in sorted(glob.glob(os.path.join(PERF_DIR, "perf-*.csv"))):
        W, H, S, I = parse(p)
        if W:
            up = W[-1]["uptime"]
            print(f"{os.path.basename(p)}  {up / 60:6.1f} min  hitches {sum(w['hitches'] for w in W) / max(up / 60, 0.01):5.1f}/min")
        else:
            print(f"{os.path.basename(p)}  (no window)")


def main():
    a = sys.argv[1:]
    if "--snapshot" in a:
        print(snapshot())
        return
    if "--list" in a:
        list_logs()
        return
    path = a[0] if a else max(glob.glob(os.path.join(PERF_DIR, "perf-*.csv")), default=None, key=os.path.getmtime)
    if not path:
        sys.exit("no perf-*.csv yet (is CyberslopPerfLog installed and has the game run?)")
    text = report(path)
    os.makedirs(REPORT_DIR, exist_ok=True)
    out = os.path.join(REPORT_DIR, os.path.basename(path).replace(".csv", ".md"))
    with open(out, "w", encoding="utf-8") as f:
        f.write(text)
    print(text)
    print("written:", out)


if __name__ == "__main__":
    main()

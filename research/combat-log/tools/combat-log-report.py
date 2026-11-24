# Reads the Cyberslop Combat Log and prints the numbers used to tune combat.
# Log files: <game>\r6\storages\CyberslopCombatLog\combat-N.txt, one per game launch.
# Usage: python -I -X utf8 combat-log-report.py [--last N] [--all] [--dir PATH] [--gamelog PATH] [--out FILE]
# Default is the newest file with combat in it. The report is also saved to logs\combat-report.md.
import argparse, collections, datetime, json, os, re, statistics

GAME = os.environ.get('CP2077_GAME_DIR', os.getcwd())  # game folder: set CP2077_GAME_DIR or run from it
LOG_DIR = os.path.join(GAME, r'r6\storages\CyberslopCombatLog')
GAMELOG = os.path.join(GAME, r'bin\x64\plugins\cyber_engine_tweaks\gamelog.log')
SCALING = os.path.join(GAME, r'bin\x64\plugins\cyber_engine_tweaks\mods\DamageScaling\settings.json')
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'logs', 'combat-report.md')
FIGHT_GAP = 30.0   # seconds without a hit or shot ends a fight
THIN = 10          # rows with fewer samples are marked as thin
RIFLE_TARGET = (8.0, 12.0)  # % of V's health per rifle round, from the balance review (fix 7)


def num(ev, key, default=0.0):
    try:
        return float(ev.get(key, default))
    except ValueError:
        return default


def pct(values, q):
    values = sorted(values)
    return values[min(len(values) - 1, int(q * len(values)))] if values else 0.0


def med(values):
    return statistics.median(values) if values else 0.0


def table(head, rows):
    out = ['| ' + ' | '.join(head) + ' |', '|' + '---|' * len(head)]
    out += ['| ' + ' | '.join(str(c) for c in r) + ' |' for r in rows]
    return out


def thin(n):
    return f'{n} (thin)' if n < THIN else str(n)


def rate(hits, rolls):
    return f'{hits / rolls * 100:.0f} %' if rolls else '-'


def read_files(paths):
    """Each file is a launch; each session line a load. A run keeps its order and own clock."""
    runs = []
    for path in paths:
        run = {'file': os.path.basename(path), 'when': os.path.getmtime(path), 'session': {}, 'events': []}
        with open(path, encoding='utf-8', errors='replace') as f:
            for line in f:
                parts = line.rstrip('\n').split('\t')
                if len(parts) < 2:
                    continue
                ev = dict(p.split('=', 1) for p in parts[1:] if '=' in p)
                ev['kind'] = parts[0]
                if parts[0] == 'session':
                    if run['events']:
                        runs.append(run)
                        run = {'file': run['file'], 'when': run['when'], 'session': ev, 'events': []}
                    else:
                        run['session'] = ev
                else:
                    run['events'].append(ev)
        if run['events'] or run['session']:
            runs.append(run)
    return runs


def fights(runs):
    found = []
    for run in runs:
        cur = []
        for ev in run['events']:
            if cur and num(ev, 't') - num(cur[-1], 't') > FIGHT_GAP:
                found.append(cur)
                cur = []
            cur.append(ev)
        if cur:
            found.append(cur)
    return found


def fight_rows(found):
    rows = []
    for i, f in enumerate(found, 1):
        took = [e for e in f if e['kind'] == 'took']
        dealt = [e for e in f if e['kind'] == 'dealt']
        if not took and not dealt:
            continue
        low = min((num(e, 'hpa') for e in took), default=100.0)
        rows.append([i, f'{num(f[-1], "t") - num(f[0], "t"):.0f} s', len(took), f'{low:.0f} %', len(dealt),
                     sum(e['kind'] == 'down' for e in f), sum(e['kind'] == 'dead' for e in f),
                     'yes' if any(e['kind'] == 'vdead' for e in f) else ''])
    return rows


def group_pct(events, key):
    groups = collections.defaultdict(list)
    for e in events:
        groups[e.get(key, 'none')].append(num(e, 'pct'))
    rows = []
    for k, v in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        rows.append([k, thin(len(v)), f'{med(v):.1f} %', f'{pct(v, 0.9):.1f} %', f'{max(v):.1f} %'])
    return rows


def shot_rows(shots, key):
    groups = collections.defaultdict(lambda: [0, 0])
    for e in shots:
        g = groups[e.get(key, '?')]
        g[0] += int(num(e, 'rolls'))
        g[1] += int(num(e, 'hits'))
    return [[k, thin(v[0]), v[1], rate(v[1], v[0])] for k, v in sorted(groups.items(), key=lambda kv: -kv[1][0])]


def drops(runs):
    """One record per NPC V hit: how the fight with it ended and which weapon finished it."""
    npcs = []
    for run in runs:
        seen = {}
        for e in run['events']:
            if e['kind'] == 'dealt':
                n = seen.setdefault(e.get('id'), {'rarity': e.get('rarity'), 'npc': e.get('npc'), 'outcome': None, 'down': None, 'broke_hp': None, 'hits': 0})
                n['wtype'] = e.get('wtype', 'none')
                n['hits'] += 1
                if e.get('broke') == 'true' and n['broke_hp'] is None:
                    n['broke_hp'] = num(e, 'hpa')
            elif e['kind'] in ('down', 'dead') and e.get('id') in seen:
                n = seen[e['id']]
                n['down' if e['kind'] == 'down' else 'outcome'] = e
        npcs += seen.values()
    return npcs


def morale_lines(path, ids):
    """Much Better AI logs each break with its exact numbers; only gamelog.log has them."""
    if not os.path.isfile(path):
        return []
    found = []
    pattern = re.compile(r'morale response assigned npc=.*?hash:(\d+) \] rarity=(\w+) posture=(\S+) hp=([\d.]+) threshold=([\d.]+) bonus=([\d.]+)')
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            m = pattern.search(line)
            if m and m.group(1) in ids:
                found.append(m.groups())
    return found


def header(runs):
    out = ['## Settings during these fights', '']
    keys = ('difficulty', 'level', 'vhp', 'varmor', 'hitmodel', 'accuracy', 'nerve', 'dying', 'headkill', 'dsheadkill', 'torsokill')
    seen = []
    rows = []
    for run in runs:
        s = tuple(run['session'].get(k, '?') for k in keys)
        if s not in seen:
            seen.append(s)
            rows.append([run['file'], datetime.datetime.fromtimestamp(run['when']).strftime('%Y-%m-%d %H:%M')] + list(s))
    out += table(['file', 'last write'] + list(keys), rows)
    if os.path.isfile(SCALING):
        try:
            cfg = json.load(open(SCALING, encoding='utf-8'))
            out += ['', f'Damage Scaling, from the settings file now (the log cannot see it): to NPCs {cfg.get("npcDamageScaling")}, to V {cfg.get("playerDamageScaling")}, headshots {cfg.get("headhshotMultiplier")}.']
        except ValueError:
            pass
    return out


def report(runs, gamelog):
    events = [e for r in runs for e in r['events']]
    took = [e for e in events if e['kind'] == 'took' and e.get('atk') != 'PressureWave' and num(e, 'dmg') > 0]
    falls = [e for e in events if e['kind'] == 'took' and e.get('atk') == 'PressureWave']
    dealt = [e for e in events if e['kind'] == 'dealt']
    shots = [e for e in events if e['kind'] == 'shots']
    npcs = drops(runs)
    found = fights(runs)
    out = ['# Combat report', '']
    out += header(runs) + ['']
    deaths = sum(e['kind'] == 'vdead' for e in events)
    out += [f'Totals: {len(found)} fights, {len(took)} hits on V, {len(dealt)} hits by V, {len(npcs)} NPCs hit, {deaths} V deaths.', '']

    out += ['## Fights', ''] + table(['#', 'length', 'hits on V', 'V lowest', 'hits by V', 'downed', 'killed', 'V died'], fight_rows(found)) + ['']

    out += ['## How hard V gets hit', '', 'Percent of V\'s maximum health per hit. Falls are left out.', '']
    out += ['By weapon class', ''] + table(['weapon', 'hits', 'median', '90 %', 'max'], group_pct(took, 'wtype')) + ['']
    out += ['By attacker rank', ''] + table(['rank', 'hits', 'median', '90 %', 'max'], group_pct(took, 'rarity')) + ['']
    rifles = [num(e, 'pct') for e in took if e.get('wtype') == 'Wea_Rifle' or e.get('wtype') == 'Wea_AssaultRifle']
    if rifles:
        low, high = RIFLE_TARGET
        m = med(rifles)
        verdict = 'inside the target' if low <= m <= high else ('below the target, V is too tough' if m < low else 'above the target, V is too fragile')
        out += [f'Rifle rounds: median {m:.1f} % over {thin(len(rifles))} hits, target {low:.0f} to {high:.0f} %: {verdict}.', '']
    if falls:
        out += [f'Falls: {len(falls)}, highest {max(num(e, "pct") for e in falls):.1f} %.', '']

    out += ['## How often NPCs hit V', '', 'Hit rolls in the aim code, so a hit here can still be dodged or blocked.', '']
    modes = {r['session'].get('hitmodel') for r in runs if r['session']}
    if modes and modes <= {'0'}:
        out += ['**Hit model is 0, so these are vanilla aim numbers.**', '']
    if not shots:
        out += ['No shots logged.', '']
    for key, title in (('range', 'By range (m)'), ('v', 'By what V was doing'), ('rarity', 'By attacker rank'), ('wtype', 'By weapon class')):
        out += [title, ''] + table([key, 'rolls', 'hits', 'rate'], shot_rows(shots, key)) + ['']

    out += ['## What V\'s hits do', '', 'By weapon class', '']
    rows = []
    groups = collections.defaultdict(list)
    for e in dealt:
        groups[e.get('wtype', 'none')].append(e)
    for k, v in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        heads = sum(e.get('zone') == 'head' for e in v)
        rows.append([k, thin(len(v)), f'{statistics.mean(num(e, "dmg") for e in v):.0f}', f'{med([num(e, "pct") for e in v]):.1f} %', rate(heads, len(v))])
    out += table(['weapon', 'hits', 'mean damage', 'median % of NPC health', 'head share'], rows) + ['']
    out += ['By what the round hit', '']
    groups = collections.Counter((e.get('zone', '?'), e.get('shape', '?')) for e in dealt)
    out += table(['zone', 'surface', 'hits'], [[z, s, n] for (z, s), n in groups.most_common()]) + ['']

    guns = [e for e in dealt if 'cut' in e and e.get('wtype', 'none') != 'none']
    if guns:
        out += ['## Enemy armor', '', 'Share of V\'s weapon hits stopped by Cyberslop Enemy Armor, by faction, rank and surface.', '']
        groups = collections.defaultdict(list)
        for e in guns:
            groups[(e.get('faction', '?'), e.get('rarity', '?'), e.get('zone', '?'), e.get('shape', '?'))].append((num(e, 'cut') * 100, num(e, 'stop', -1) * 100))
        rows = []
        for k, v in sorted(groups.items(), key=lambda kv: -len(kv[1])):
            stops = [s for _, s in v if s >= 0]
            rows.append([*k, thin(len(v)), f'{med([c for c, _ in v]):.0f} %', f'{max(c for c, _ in v):.0f} %', f'{med(stops):.0f} %' if stops else '-'])
        out += ['median stop = everything armor took off, vanilla Armor included (Combat Log 1.3.0 and later).', '']
        out += table(['faction', 'rank', 'zone', 'surface', 'hits', 'median cut', 'max cut', 'median stop'], rows) + ['']
        pierce = sorted({(e.get('wpn', '?'), e['ap']) for e in guns if 'ap' in e})
        if pierce:
            out += ['Armor penetration stat on these weapons (it caps at 1).', ''] + table(['weapon', 'ap'], [list(r) for r in pierce]) + ['']

    machines = [e for e in dealt if e.get('type') in ('Drone', 'Mech')]
    if machines:
        out += ['## Drones and mechs', '', 'V\'s hits on machines. vanilla = Armor before Enemy Armor\'s hand-out, armor = at the hit (after wear).', '']
        groups = collections.defaultdict(list)
        for e in machines:
            groups[e.get('npc', '?').replace('Character.', '')].append(e)
        rows = []
        for k, v in sorted(groups.items(), key=lambda kv: -len(kv[1])):
            vanilla = [num(e, 'varm') for e in v if e.get('varm', '-') != '-']
            stops = [num(e, 'stop') * 100 for e in v if 'stop' in e]
            rows.append([k, v[0].get('rarity', '?'), thin(len(v)), f'{med(vanilla):.0f}' if vanilla else '-', f'{med([num(e, "armor") for e in v]):.0f}',
                         f'{med(stops):.0f} %' if stops else '-', f'{med([num(e, "pct") for e in v]):.1f} %', sum('weakspot' in e.get('flags', '') for e in v)])
        out += table(['record', 'rank', 'hits', 'vanilla', 'armor', 'median stop', 'median % of health', 'weakspot hits'], rows) + ['']

    brawls = [e for e in events if e['kind'] == 'npcfight']
    if brawls:
        out += ['## NPC fights', '', 'Hits between NPCs (and turrets, cars) on NPCs, summed in 5 s windows. stop = share armor took off, per hit.', '']
        for title, keys in (('By target', ('type', 'rarity', 'faction')), ('By surface hit', ('type', 'zone', 'shape')), ('By attacker and weapon', ('by', 'wtype'))):
            groups = collections.defaultdict(lambda: [0, 0, 0, 0.0, 0.0, 0.0])
            for e in brawls:
                g = groups[tuple(e.get(k, '?') for k in keys)]
                n = num(e, 'hits')
                g[0] += n; g[1] += num(e, 'stopped'); g[2] += num(e, 'kills'); g[3] += num(e, 'stop') * n; g[4] += num(e, 'raw'); g[5] += num(e, 'dmg')
            rows = [[*k, thin(int(g[0])), rate(g[1], g[0]), f'{g[3] / g[0] * 100:.0f} %', f'{g[4] / g[0]:.1f}', f'{g[5] / g[0]:.1f}', int(g[2])]
                    for k, g in sorted(groups.items(), key=lambda kv: -kv[1][0]) if g[0] > 0]
            out += [title, ''] + table([*keys, 'hits', 'armored hits', 'mean stop', 'raw / hit', 'dealt / hit', 'kills'], rows) + ['']

    out += ['## Hits to drop an NPC', '', 'Hits by V until the NPC went down or died, by the weapon that landed the last hit.', '']
    rows = []
    groups = collections.defaultdict(list)
    for n in npcs:
        end = n['down'] or n['outcome']
        if end:
            groups[(n.get('wtype'), n['rarity'])].append((num(end, 'hits'), num(end, 'secs')))
    for (w, r), v in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        rows.append([w, r, thin(len(v)), f'{med([x[0] for x in v]):.0f}', f'{med([x[1] for x in v]):.1f} s'])
    out += table(['weapon', 'rank', 'NPCs', 'median hits', 'median time'], rows) + ['']

    out += ['## How fights with NPCs ended', '']
    rows = []
    groups = collections.defaultdict(list)
    for n in npcs:
        groups[n['rarity']].append(n)
    for r, v in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        downed = sum(1 for n in v if n['down'])
        dead = sum(1 for n in v if n['outcome'])
        broke = [n['broke_hp'] for n in v if n['broke_hp'] is not None]
        left = sum(1 for n in v if not n['down'] and not n['outcome'])
        rows.append([r, thin(len(v)), downed, dead, len(broke), left])
    out += table(['rank', 'NPCs hit', 'went down', 'died', 'morale broke', 'neither'], rows) + ['']
    ids = {e.get('id') for e in dealt}
    breaks = morale_lines(gamelog, ids)
    if breaks:
        rows = [[r, p, thin(len(v)), f'{med(v):.0f} %'] for (r, p), v in sorted(_by_rank(breaks).items())]
        out += ['Morale breaks with Much Better AI\'s own numbers (gamelog.log, latest launch only)', ''] + table(['rank', 'temperament', 'breaks', 'median health at break'], rows) + ['']
    return out


def _by_rank(breaks):
    groups = collections.defaultdict(list)
    for _, rarity, posture, hp, *_rest in breaks:
        groups[(rarity, posture)].append(float(hp) * 100)
    return groups


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--last', type=int, default=1, help='newest N log files that have combat in them')
    ap.add_argument('--all', action='store_true')
    ap.add_argument('--dir', default=LOG_DIR)
    ap.add_argument('--gamelog', default=GAMELOG)
    ap.add_argument('--out', default=OUT)
    args = ap.parse_args()
    if not os.path.isdir(args.dir):
        print('No log folder yet:', args.dir)
        return
    # The file numbers are not in launch order, so the last write decides what is newest
    names = sorted((n for n in os.listdir(args.dir) if n.startswith('combat-')), key=lambda n: os.path.getmtime(os.path.join(args.dir, n)))
    paths = [os.path.join(args.dir, n) for n in names if os.path.getsize(os.path.join(args.dir, n)) > 0]
    paths = [p for p in paths if any(l.split('\t')[0] in ('took', 'dealt', 'npcfight') for l in open(p, encoding='utf-8', errors='replace'))]
    if not paths:
        print('No combat logged yet in', args.dir)
        return
    runs = read_files(paths if args.all else paths[-args.last:])
    text = '\n'.join(report(runs, args.gamelog))
    print(text)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, 'w', encoding='utf-8') as f:
        f.write(text + '\n')


if __name__ == '__main__':
    main()

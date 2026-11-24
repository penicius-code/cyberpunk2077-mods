# Cyberslop Gore Probe report (1.0.0 and 1.1.0 logs): where does gore stop at range, and why.
# Usage: python -I -X utf8 gore_probe_report.py [gore-N.txt | folder]   (default: newest file in the game's storage)
# Reads r6\storages\CyberslopGoreProbe\gore-N.txt and prints, per distance band, the funnel from shot to confirmed cut,
# the force-cut engine test, the far-cut experiment, what V marked as seen, and an automatic verdict.
import os, sys, re, statistics
from collections import defaultdict, Counter

STORE = os.path.join(os.environ.get('CP2077_GAME_DIR', os.getcwd()), r'r6\storages\CyberslopGoreProbe')  # set CP2077_GAME_DIR to the game folder
BANDS = [(0, 10), (10, 25), (25, 50), (50, 75), (75, 100), (100, 10000)]


def band(d):
    for lo, hi in BANDS:
        if lo <= d < hi:
            return f'{lo}-{hi}' if hi < 10000 else f'{lo}+'
    return '?'


def band_names():
    return [f'{lo}-{hi}' if hi < 10000 else f'{lo}+' for lo, hi in BANDS]


def pick_file(arg):
    path = arg or STORE
    if os.path.isdir(path):
        files = [os.path.join(path, f) for f in os.listdir(path) if re.match(r'gore-\d+\.txt$', f)]
        if not files:
            sys.exit('no gore-N.txt in ' + path)
        return max(files, key=os.path.getmtime)
    return path


def parse(path):
    rows = []
    for raw in open(path, encoding='utf-8', errors='replace'):
        raw = raw.rstrip('\n')
        if not raw:
            continue
        parts = raw.split('\t')
        row = {'kind': parts[0]}
        for p in parts[1:]:
            if '=' in p:
                k, v = p.split('=', 1)
                row[k] = v
        rows.append(row)
    return rows


def f(row, key, default=-1.0):
    try:
        return float(row.get(key, default))
    except ValueError:
        return default


def pct(a, b):
    return f'{a}/{b}' + (f' ({100 * a / b:.0f}%)' if b else '')


def main():
    path = pick_file(sys.argv[1] if len(sys.argv) > 1 else None)
    rows = parse(path)
    print(f'Gore Probe report: {path}  ({len(rows)} rows)')
    for r in rows:
        if r['kind'] in ('probe', 'session', 'experiment', 'autoAB'):
            print('  ' + r['kind'] + ' ' + ' '.join(f'{k}={v}' for k, v in r.items() if k != 'kind'))
    tallies = [r for r in rows if r['kind'] == 'tally']
    if tallies:
        last = tallies[-1]
        print(f"  not written (1.1.0 filter): {last.get('skippedNear')} near ranged hits without kill / cut, {last.get('skippedMelee')} melee hits; {last.get('hits')} ranged hits evaluated, {last.get('reqs')} cut requests")

    hits = [r for r in rows if r['kind'] == 'hit']
    raws = [r for r in rows if r['kind'] == 'raw']
    reqs = {r['req']: r for r in rows if r['kind'] == 'req'}
    cuts = defaultdict(dict)
    for r in rows:
        if r['kind'] == 'cut':
            cuts[r['req']][r['after']] = r
    seens = [r for r in rows if r['kind'] == 'seen']
    natives = [r for r in rows if r['kind'] == 'native']

    # 1. upstream gate: hits of V's that never asked for a hit reaction
    print('\n1. Upstream gate (NPCPuppet.ShouldRequestHitReaction): V ranged hits per band, reaction requested')
    print('   (1.1.0 writes these rows only when the gate blocks or from 25 m, so near bands show blocked hits only)')
    g = defaultdict(Counter)
    for r in raws:
        if r.get('atk') in ('Effect',):
            continue
        b = band(f(r, 'dist'))
        g[b]['all'] += 1
        g[b]['req'] += r.get('reaction') == '1'
    for b in band_names():
        if g[b]['all']:
            print(f'   {b:>8} m  {pct(g[b]["req"], g[b]["all"])}')

    # 2. funnel for ranged hits
    ranged = [h for h in hits if h.get('atk') in ('Ranged', 'Direct', 'PressureWave', 'WhipAttack')]
    print('\n2. Ranged hits (EvaluateHit reached), per band: shapes found, pwd = ProcessWoundsAndDismemberment entered,')
    print('   dc = DismembermentConditions true at least once, req = cut requested, cut = limb count rose within 3 s')
    print('   (1.1.0: under 25 m only kills and cut requests are written; 25 m+ every ranged hit)')
    hdr = f'   {"band":>8}  {"hits":>5} {"noShape":>8} {"pwd":>5} {"dc":>5} {"req":>5} {"cut":>5} {"drop":>5}  {"fov med":>7}  {"kills":>5} {"killReq":>7}'
    print(hdr)
    per = defaultdict(list)
    for h in ranged:
        per[band(f(h, 'dist'))].append(h)
    hit_req_ids = defaultdict(list)
    for q in reqs.values():
        if q.get('seq', '-') != '-':
            hit_req_ids[q['seq']].append(q['req'])
    for b in band_names():
        hs = per[b]
        if not hs:
            continue
        no_shape = sum(h.get('shapes') == '0' for h in hs)
        pwd = sum(h.get('pwd') == '1' for h in hs)
        dc = sum('1' in h.get('dc', '') for h in hs)
        req = sum(bool(h.get('req')) for h in hs)
        cut = drop = 0
        for h in hs:
            for rq in hit_req_ids.get(h['seq'], []):
                v = cuts.get(rq, {}).get('3s', {}).get('verdict')
                cut += v == 'cut'
                drop += v == 'nochange'
        fovs = [f(h, 'fov') for h in hs if f(h, 'fov') > 0]
        kills = [h for h in hs if h.get('alivePre') == '1' and h.get('aliveNow') == '0']
        kreq = sum(bool(h.get('req')) for h in kills)
        print(f'   {b:>8}  {len(hs):>5} {no_shape:>8} {pwd:>5} {dc:>5} {req:>5} {cut:>5} {drop:>5}  {statistics.median(fovs) if fovs else -1:>7.1f}  {len(kills):>5} {kreq:>7}')

    # 3. why kill shots at range got no cut
    print('\n3. Kill shots (alive before, dead after) without a cut request, by band: which gate stopped them')
    reasons = defaultdict(Counter)
    for h in ranged:
        if not (h.get('alivePre') == '1' and h.get('aliveNow') == '0') or h.get('req'):
            continue
        b = band(f(h, 'dist'))
        if h.get('shapes') == '0':
            reasons[b]['no hit shape (hit LOD)'] += 1
        elif h.get('pwd') != '1':
            reasons[b]['pwd not entered (hit timer / grapple / mounted)'] += 1
        elif h.get('canDie') == '0':
            reasons[b]['CanDieCondition false (nonlethal / boss / god mode)'] += 1
        elif h.get('dc', '') == '' :
            reasons[b]['DismembermentConditions never called (early return or other wrap)'] += 1
        elif '1' not in h.get('dc', ''):
            cum, thr = f(h, 'cum'), f(h, 'thr')
            tag = f'threshold not reached' if thr > 0 and cum < thr else ('threshold 0 (zone has none)' if thr <= 0 else 'dc false (alive / other)')
            reasons[b][tag] += 1
        else:
            reasons[b]['dc true but no request (another wrap dropped it)'] += 1
    for b in band_names():
        if reasons[b]:
            print(f'   {b:>8} m  ' + ', '.join(f'{k}: {v}' for k, v in reasons[b].most_common()))

    # damage vs threshold for head / limb kill shots
    print('\n   cum / thr (dismember damage vs threshold) for ranged kill shots, median per band and zone:')
    ct = defaultdict(list)
    for h in ranged:
        if h.get('alivePre') == '1' and h.get('aliveNow') == '0' and f(h, 'thr') > 0:
            ct[(band(f(h, 'dist')), h.get('zone'))].append(f(h, 'cum') / f(h, 'thr'))
    for (b, z), v in sorted(ct.items()):
        print(f'   {b:>8} m {z:<12} n={len(v):<3} median ratio {statistics.median(v):.2f} (>= 1 cuts)')

    # 4. engine test: forced cuts and every request, by band and part
    def req_table(title, keep):
        print('\n' + title)
        t = defaultdict(Counter)
        for q in reqs.values():
            if not keep(q):
                continue
            v = cuts.get(q['req'], {}).get('3s', {}).get('verdict', 'nocheck')
            key = (band(f(q, 'dist')), q.get('part'), q.get('wound'))
            t[key][v] += 1
        if not t:
            print('   none')
        for (b, p, w), c in sorted(t.items()):
            print(f'   {b:>8} m {p:<10} {w:<7} ' + ', '.join(f'{k}: {v}' for k, v in c.most_common()))
        return t

    forced = req_table('4. Forced cuts (hotkey), 3 s verdict: does the ENGINE cut at range?', lambda q: q.get('src') == 'force')
    req_table('5a. Far-cut experiment (forced on ranged kill shots that got none)', lambda q: q.get('src') == 'exp')
    ab = req_table('5b. Automatic A/B, forced half (ranged kill shots from 30 m that got no cut), 3 s verdict', lambda q: q.get('src') == 'ab')
    print('   A/B control half (left untouched, no cut), by band and part:')
    ctl = Counter((band(f(h, 'dist')), h.get('exp', '').split(':', 1)[-1]) for h in hits if h.get('exp', '').startswith('ab-control'))
    if not ctl:
        print('   none')
    for (b, p), n in sorted(ctl.items()):
        print(f'   {b:>8} m {p:<10} {n}')
    req_table('6. Every game cut request (src=hit / other), 3 s verdict', lambda q: q.get('src') in ('hit', 'other'))

    # 7. what V saw
    print('\n7. V\'s marks (seen gore yes / no) by band')
    s = defaultdict(Counter)
    for r in seens:
        s[band(f(r, 'dist'))]['yes' if r.get('gore') == '1' else 'no'] += 1
    for b in band_names():
        if s[b]:
            print(f'   {b:>8} m  yes {s[b]["yes"]}  no {s[b]["no"]}')
    hit_by_seq = {h['seq']: h for h in hits}
    for r in seens:
        h = hit_by_seq.get(r.get('seq'))
        if h:
            got = [cuts.get(q, {}).get('3s', {}).get('verdict', '?') for q in hit_req_ids.get(h['seq'], [])]
            print(f'   seq {r["seq"]:>4} {f(r, "dist"):6.1f} m seen={r.get("gore")} log: zone={h.get("zone")} req={h.get("req") or "-"} cut={",".join(got) or "-"} fov={h.get("fov")}')

    # 8. verdict
    print('\n8. Verdict')
    def rate(t, near):
        c = Counter()
        for (b, p, w), v in t.items():
            lo = int(b.split('-')[0].rstrip('+'))
            if (lo < 25) == near and w == 'COARSE':
                c.update(v)
        return c
    # every COARSE request is evidence of what the engine does at that distance, whoever asked (game, A/B, hotkey)
    allreq = defaultdict(Counter)
    for q in reqs.values():
        v = cuts.get(q['req'], {}).get('3s', {}).get('verdict', 'nocheck')
        allreq[(band(f(q, 'dist')), q.get('part'), q.get('wound'))][v] += 1
    near, far = rate(allreq, True), rate(allreq, False)
    print(f"   COARSE cut requests under 25 m: landed {near['cut']}, no change {near['nochange']}; 25 m+: landed {far['cut']}, no change {far['nochange']}")
    if far['cut'] or far['nochange']:
        if far['cut'] and not far['nochange']:
            print('   ENGINE CUTS AT RANGE: every COARSE cut at 25 m+ landed -> the limit is in scripts or data (section 3 names the gate), fixable; the A/B forced half is the fix prototype.')
        elif far['nochange'] and not far['cut']:
            print('   ENGINE DROPS CUTS AT RANGE: no COARSE cut at 25 m+ landed' + (' while near ones did' if near['cut'] else '') + ' -> native limit (mesh LOD); needs a RED4ext plugin or forced LOD.')
        else:
            print(f'   MIXED: at 25 m+ {far["cut"]} landed, {far["nochange"]} did not -> compare dist / fov / part per row in sections 4-6.')
    else:
        print('   No cut request at 25 m+ yet: get a few ranged kill shots from 30 m+ (A/B forces every second one) or use the cut hotkey.')
    print('   Section 3 names the gate that stops kill shots in each band; section 5 shows whether forcing a cut fixes it.')


if __name__ == '__main__':
    main()

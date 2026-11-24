# Cyberslop Cashflow report: reads r6\storages\CyberslopCashflow\cashflow.txt (CSV written by the mod)
# and prints where the eddies came from and went, per real hour of play and per game day.
# usage: python -I -X utf8 cashflow_report.py [path to cashflow.txt] [--days N]
import sys, csv, os, collections

DEFAULT = os.path.join('r6', 'storages', 'CyberslopCashflow', 'cashflow.txt')  # relative to the game folder
args = [a for a in sys.argv[1:] if not a.startswith('--')]
path = args[0] if args else DEFAULT
last_days = None
if '--days' in sys.argv:
    last_days = int(sys.argv[sys.argv.index('--days') + 1])

rows = []
with open(path, encoding='utf-8', errors='replace', newline='') as f:
    for r in csv.DictReader(f):
        try:
            r['delta'] = int(r['delta'])
            r['balance'] = int(r['balance'])
            r['session_s'] = int(r['session_s'])
            r['game_day'] = int(r['game_day'])
        except (ValueError, KeyError, TypeError):
            continue
        rows.append(r)
if not rows:
    sys.exit('no rows in ' + path)
if last_days:
    top = max(r['game_day'] for r in rows)
    rows = [r for r in rows if r['game_day'] > top - last_days]

# Real play time: per launch, last minus first timestamp (heartbeats every 5 real minutes keep it honest).
span = collections.defaultdict(lambda: [10 ** 12, -1])
for r in rows:
    s = span[r['launch']]
    s[0] = min(s[0], r['session_s'])
    s[1] = max(s[1], r['session_s'])
real_h = sum(max(0, b - a) for a, b in span.values()) / 3600.0
days = sorted(set(r['game_day'] for r in rows))
game_days = max(1, len(days))

money = [r for r in rows if r['source'] not in ('heartbeat', 'statement')]
scene = [r for r in money if r['source'] == 'scene']
money = [r for r in money if r['source'] != 'scene']
inc = collections.Counter()
out = collections.Counter()
for r in money:
    if r['delta'] > 0:
        inc[r['source']] += r['delta']
    else:
        out[r['source']] -= r['delta']
tin, tout = sum(inc.values()), sum(out.values())

def per(v, d):
    return '%9.0f' % (v / d) if d > 0 else '      n/a'

print('Cyberslop Cashflow report | %s' % path)
print('rows %d (%d money, %d scene swaps ignored) | launches %d | real play %.1f h | game days %d (%s..%s)' % (
    len(rows), len(money), len(scene), len(span), real_h, game_days, days[0], days[-1]))
print()
print('%-12s %12s %10s %10s' % ('IN', 'total', '/real h', '/game day'))
for k, v in inc.most_common():
    print('%-12s %12d %10s %10s' % (k, v, per(v, real_h), per(v, game_days)))
print('%-12s %12d %10s %10s' % ('= in', tin, per(tin, real_h), per(tin, game_days)))
print()
print('%-12s %12s %10s %10s' % ('OUT', 'total', '/real h', '/game day'))
for k, v in out.most_common():
    print('%-12s %12d %10s %10s' % (k, v, per(v, real_h), per(v, game_days)))
print('%-12s %12d %10s %10s' % ('= out', tout, per(tout, real_h), per(tout, game_days)))
print()
print('NET %+d | %s per real hour | %s per game day' % (tin - tout, per(tin - tout, real_h).strip(), per(tin - tout, game_days).strip()))
print()
print('Per game day:')
print('%-6s %10s %10s %10s %10s  biggest in / biggest out' % ('day', 'in', 'out', 'net', 'balance'))
for d in days:
    dm = [r for r in money if r['game_day'] == d]
    di = collections.Counter()
    do = collections.Counter()
    for r in dm:
        (di if r['delta'] > 0 else do)[r['source']] += abs(r['delta'])
    bal = [r['balance'] for r in rows if r['game_day'] == d]
    bi = di.most_common(1)
    bo = do.most_common(1)
    print('%-6d %10d %10d %+10d %10d  %s / %s' % (d, sum(di.values()), sum(do.values()), sum(di.values()) - sum(do.values()),
          bal[-1] if bal else 0, ('%s %d' % bi[0]) if bi else '-', ('%s %d' % bo[0]) if bo else '-'))
print()
print('Largest single changes:')
for r in sorted(money, key=lambda r: -abs(r['delta']))[:12]:
    print('  day %d %s %+8d  %-10s %s' % (r['game_day'], r['game_clock'], r['delta'], r['source'], r.get('detail', '')))
other = [r for r in money if r['source'] == 'other']
if other:
    print()
    print('Untagged ("other") changes: %d, in %d, out %d. Biggest:' % (len(other), sum(r['delta'] for r in other if r['delta'] > 0),
          -sum(r['delta'] for r in other if r['delta'] < 0)))
    for r in sorted(other, key=lambda r: -abs(r['delta']))[:8]:
        print('  day %d %s %+8d' % (r['game_day'], r['game_clock'], r['delta']))

"""Offline bounded BFS for authored Classic data. No runtime generation."""
import hashlib
import collections
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def solve(tubes, limit=300000):
    start = tuple(map(tuple, tubes))
    queue = collections.deque([(start, [])])
    seen = {tuple(sorted(start))}
    while queue:
        state, path = queue.popleft()
        if all(not t or len(t) == 4 and len(set(t)) == 1 for t in state):
            return {"moves": len(path), "expanded": len(seen), "solution": path}
        for i, source in enumerate(state):
            if not source:
                continue
            for j, target in enumerate(state):
                if i == j or len(target) == 4 or target and target[-1] != source[-1]:
                    continue
                count = 1
                while count < len(source) and source[-count-1] == source[-1]:
                    count += 1
                count = min(count, 4-len(target))
                nxt = list(state)
                nxt[i], nxt[j] = source[:-count], target + source[-count:]
                key = tuple(sorted(nxt))
                if key in seen:
                    continue
                seen.add(key)
                if len(seen) > limit:
                    raise ValueError('solver budget exceeded')
                queue.append((tuple(nxt), path + [[i, j]]))
    raise ValueError('unsolvable')

def main():
    ids = json.loads((ROOT/'content/levels/catalog.json').read_text())['available_level_ids']
    assert ids == [f'level_{i:03}' for i in range(1,16)]
    # Existing save snapshots require these exact content-version-1 fixture bytes.
    legacy = {'level_001': '554542e68c1f39c0e466f3aad75a88be5c0498b594f77b284df3deb568667508', 'level_002': '96c4eeeecb37baf9b262145bc73f043cef92ca1bc982e0f7c7c3da103f24809f'}
    for name, digest in legacy.items():
        assert hashlib.sha256((ROOT/f"content/levels/{name}.json").read_bytes()).hexdigest() == digest
    results = {}
    # Circuit15 is verified by production MoveRules in tests/g5/circuit_test.gd.
    # This solver remains Classic-only; never solve Circuit while ignoring locks.
    for name in ids[:14]:
        data = json.loads((ROOT/f'content/levels/{name}.json').read_text())
        assert data['mechanics'] == []
        results[name] = solve(data['tubes_bottom_to_top'])
    expected = json.loads((ROOT/'tests/campaign/solutions.json').read_text())
    assert results == {name: expected[name] for name in ids[:14]}, 'authored content or solver metrics changed; review explicitly'
    easy = [results[f'level_{i:03}']['moves'] for i in range(6,11)]
    hard = [results[f'level_{i:03}']['moves'] for i in range(11,15)]
    assert max(easy) < min(hard) and all(a < b for a,b in zip(hard, hard[1:]))
    print(json.dumps(results, indent=2))

if __name__ == '__main__':
    main()

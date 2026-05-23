# darshini — bench baseline

Captured 2026-05-23 at v0.9.0 via `cyrius bench
tests/darshini.bcyr` on the maintainer's x86_64 Linux box.
Pure-algorithm benchmarks — filesystem I/O excluded (those vary
with kernel page cache + fs state and are dominated by syscall
overhead, not by darshini's code).

| Path                          | Iters    | Avg     | Notes |
|-------------------------------|----------|---------|-------|
| `sort_entries` best=5         | 100 000  | 578 ns  | Already-sorted 5-entry; pure scan. |
| `sort_entries` best=100       |  10 000  | 11 µs   | Already-sorted 100-entry; ~110 ns/entry. |
| `sort_entries` best=1000      |   1 000  | 112 µs  | Already-sorted 1000-entry; ~110 ns/entry — linear in N for best case (no shifts). |
| `sort_entries` worst=100      |   1 000  | 394 µs  | Reverse-sorted 100-entry; O(N²) shifts. |
| `sort_entries` worst=1000     |     100  | 36.2 ms | Reverse-sorted 1000-entry; O(N²) shifts. **Hot-path candidate** for a merge-sort upgrade post-v1. |
| `pick_cols` 1k@80, no-decor   |  10 000  | 177 µs  | Iterates column counts, recomputing per-col widths. Sub-frame at typical entry counts. |
| `pick_cols` 1k@200, icons+git |  10 000  | 133 µs  | Wider TTY → fewer iterations before fit. |
| `color_for_mode` (dir)        | 1 000 000|   3 ns  | Pure mode-bit dispatch; effectively free. |
| `icon_for_entry` `.cyr`       | 100 000  | 345 ns  | Walk the lookup chain (filename → prefix → type → ext → generic). |
| `mime_for_entry` `.md`        | 100 000  | 615 ns  | Same shape as icon, longer chain (inode → filename → ext → exec → magic → fallback). |

## Real-world cost per listing

Typical home-directory listing (100 entries, already-sorted):
- `sort_entries`: ~11 µs
- `pick_cols` (TTY width 200): ~13 µs (scales linearly with N for the column-width compute)
- Per-entry decoration picks: 100 × (3 + 345 + 615) ≈ 96 µs
- **Algorithmic total: ~120 µs.** Dwarfed by the per-entry `lstat(2)` (~3-5 µs each = 300-500 µs total).

Worst-case 1k-entry reverse-sorted directory under `-l --git --mime`:
- `sort_entries` worst: 36 ms — dominant
- `pick_cols`: 177 µs
- Decoration: 1000 × ~1 µs = 1 ms
- 1000 lstats: ~3-5 ms
- 1000 git linear-scan lookups: O(N²) on the tracked vec — also a follow-up
- **Total: 40-50 ms.** Noticeable but acceptable for v1.0 (`tree` in a deep node_modules behaves similarly).

## Optimization candidates (post-v1)

1. **Merge-sort replacement for `sort_entries`**. Removes the
   O(N²) worst case. Estimated ship: v1.1 if user feedback flags
   the 1k-reverse case as a real pain point. The maintainer's
   daily-use directories (this repo, dotfiles, home directory)
   are < 100 entries, so deferring is safe.
2. **Hashmap for tracked-paths lookup in `git_status_for`**.
   Currently linear-scan; for repos > ~5k tracked files the
   `--git` cost goes quadratic. Same v1.1 trigger.
3. **Mime magic-probe caching**. Repeated invocations on the
   same directory re-open and re-read the first 16 bytes of
   every extensionless file. A persistent (LRU?) cache between
   invocations would amortize. Probably overkill — most
   listings don't re-run within seconds.
4. **Replace per-entry `path_join` allocation** with a stack
   buffer. The current code mallocs a fresh path per entry per
   decoration pass. Net pressure on the bump allocator.

None of these block v1.0. They go on the v1.1+ enhancement
backlog if the maintainer hits them in real use.

## How to reproduce

```sh
cyrius build src/main.cyr build/darshini       # cleanliness check
cyrius bench tests/darshini.bcyr               # run this set
# Capture new numbers + diff into a follow-up section here.
```

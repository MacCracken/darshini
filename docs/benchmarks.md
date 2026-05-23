# darshini — bench baseline

Captured 2026-05-23 at v0.9.0 via `cyrius bench
tests/darshini.bcyr` on the maintainer's x86_64 Linux box.
**Refreshed 2026-05-23 at v1.1.0** after the merge-sort +
git-hashmap upgrades — diff section at the bottom.
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

## v1.1.0 refresh — 2026-05-23

After the merge-sort upgrade (eliminates O(N²) worst case)
and the git tracked-set hashmap (linear-scan → O(1) avg).

| Path                          | v0.9.0   | v1.1.0   | Δ |
|-------------------------------|----------|----------|---|
| `sort_entries` best=5         | 578 ns   | 1 µs     | 1.7× slower (merge-sort overhead at tiny N) |
| `sort_entries` best=100       | 11 µs    | 44 µs    | 4× slower |
| `sort_entries` best=1000      | 112 µs   | 635 µs   | 5.6× slower |
| `sort_entries` worst=100      | 394 µs   | 48 µs    | **8× faster** |
| `sort_entries` worst=1000     | 36.2 ms  | 640 µs   | **56× faster** |
| `pick_cols` 1k@80 no-decor    | 177 µs   | 177 µs   | flat |
| `pick_cols` 1k@200 icons+git  | 133 µs   | 133 µs   | flat |
| `color_for_mode` (dir)        | 3 ns     | 3 ns     | flat |
| `icon_for_entry` `.cyr`       | 345 ns   | 380 ns   | flat (within noise) |
| `mime_for_entry` `.md`        | 615 ns   | 623 ns   | flat |

**Verdict**: trade was right. The worst-case sort path was
36 ms — perceptible. Now it's sub-ms across the board. The
best-case regression (5.6× at 1k) sits at 635 µs total — still
well under any perception threshold and dwarfed by the actual
`lstat(2)` syscall cost on the same listing.

Git hashmap delta isn't visible at this repo's 117-file index
size (linear scan was already sub-µs). The win lands at
~5k+ tracked files where the linear-scan goes quadratic — that
upgrade is preemptive for large-repo users, not a measurable
improvement at typical scales.

### v1.2 hot-path optimization candidates

- ~~Hybrid sort~~ — **shipped in v1.1.2.** Insertion-sort cutoff
  at the merge-sort leaves (< 16 elements). Restored best-case
  perf at small N; slight regression on the
  fully-reverse-sorted worst case (acceptable: real-world
  directories are nearly-sorted, not adversarial).
- ~~`pick_cols` early-out~~ — **shipped in v1.1.2.** Widest-aware
  short-circuit returns 1 col immediately when the widest entry
  doesn't fit. Skips the full per-col iteration loop.
- ~~`path_join` buffer reuse~~ — **shipped in v1.1.2.** Local
  `_path_join_into` helper writes into a per-listing stack
  buffer. `compute_decor` uses it; lib/fs.cyr's `path_join`
  stays for cases where caller-owned allocation is needed
  (tree.cyr's recursion).

## v1.1.2 refresh — 2026-05-23

| Path                                            | v1.1.0   | v1.1.1   | v1.1.2   | Δ vs 1.0 |
|-------------------------------------------------|----------|----------|----------|----------|
| `sort_entries` best=5                           | 1 µs     | 1 µs     | 726 ns   | 1.4× slower than v1.0's 578 ns, but better than v1.1.0 |
| `sort_entries` best=100                         | 44 µs    | 44 µs    | 30 µs    | 2.7× slower than v1.0's 11 µs (insertion was unbeatable here) |
| `sort_entries` best=1000                        | 635 µs   | 635 µs   | 493 µs   | 4.4× slower than v1.0's 112 µs |
| `sort_entries` worst=100                        | 48 µs    | 48 µs    | 70 µs    | **5.6× faster than v1.0's 394 µs** |
| `sort_entries` worst=1000                       | 640 µs   | 640 µs   | 820 µs   | **44× faster than v1.0's 36.2 ms** |
| `pick_cols` 1k@80 no-decor                      | 177 µs   | 177 µs   | 182 µs   | flat |
| `pick_cols` 1k@200 icons+git                    | 133 µs   | 133 µs   | 139 µs   | flat |
| `pick_cols` 1k@10 widest-doesnt-fit (early-out) | n/a      | n/a      | 33 µs    | new bench; was full iteration before |
| `path_join` (str_builder)                       | n/a      | n/a      | 305 ns   | reference: the v1.0 path |
| `_path_join_into` (buf reuse)                   | n/a      | n/a      | 72 ns    | **4.2× faster** — used by compute_decor |
| `color_for_mode` (dir)                          | 3 ns     | 3 ns     | 3 ns     | flat |
| `icon_for_entry` `.cyr`                         | 380 ns   | 380 ns   | 368 ns   | flat (within noise) |
| `mime_for_entry` `.md`                          | 623 ns   | 623 ns   | 614 ns   | flat |

**Verdict on the sort trade**: v1.1.2 best-case (already-
sorted, which is what real-world directories overwhelmingly
look like) recovered most of the v1.1.0 regression while
keeping the v1.0→v1.1 worst-case win largely intact (still
44× faster than v1.0). Worst-case absolute is ~820 µs — well
under any perception threshold.

**Verdict on `_path_join_into`**: 4.2× per-call cost reduction.
At a 1000-entry listing under `-l --git --mime`, that saves
~233 µs of pure path-join work (1000 × 233 ns) — meaningful
but secondary to the larger lstat + per-entry decoration costs.

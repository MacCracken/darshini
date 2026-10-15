# 003 — `alloc()` is a bump allocator with no free, and the process is the deallocator

**Applies to**: every `alloc()` call in `src/`.

darshini's default allocator has **no free**. `alloc()` moves a pointer
forward and never gives memory back. This is a deliberate fit for the shape of
the program — CLAUDE.md's "single-pass render": the user invokes, we walk, we
render, we exit. The process *is* the deallocator, and it runs for
milliseconds.

Two consequences that are not visible at a call site:

**Anything allocated per entry is permanently retained for the run.** The
2026-05-23 audit recorded this as MINOR-1 and accepted it: the per-listing
footprint scales with N, and that is fine because the binary dies immediately
after. It stops being fine only if darshini ever grows a long-lived mode (a
watch loop, a daemon, a library embedding). None of those are on the roadmap;
if one ever is, this note is the thing to re-read first.

**A scratch buffer inside a loop is not free.** cycc 6.5.11 moved the stdlib
`dir_list` / `is_dir` 4 KB `getdents` scratch from `alloc()` to a stack local
precisely because of this — upstream measured 4104 bytes burned *per call*.
darshini's Linux path picked that up automatically at v1.3.1 by re-vendoring;
its agnos mirror `_d_dir_list_agnos` got the same fix at v1.3.3 and was
retired for the stdlib's own agnos arm at v1.4.1. The same release moved
`-T`'s per-entry stat buffer and `-l` formatter scratch to the stack — they
were `alloc()`s per entry, ~200 dead bytes each, carried to exit. What is
still retained per entry is inherent to the shape: the entry name, its path
join, and (under `-l` / decoration) its stat buffer in the decoration vecs.
Measured at v1.4.1: `-T` over 80k entries peaks at ~35 MB RSS. The 64 KB
stdout buffer (v1.4.1) is one allocation for the run.

**When to use which**: `alloc()` for anything whose lifetime is the run (the
entries vec, the decoration vecs, the parsed git index). `fl_alloc()` /
`fl_free()` — the freelist — for data with an individual lifetime. A stack
`var buf[N]` for scratch that dies at the end of the function, which is
almost always the right answer inside a loop. See
[001](001-var-buf-is-bytes.md) for how to size those.

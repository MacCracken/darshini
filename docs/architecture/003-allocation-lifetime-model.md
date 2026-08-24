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
darshini's Linux path picked that up automatically at v1.3.1 by re-vendoring.
Its agnos mirror `_d_dir_list_agnos` (`walk.cyr`) still calls `alloc(4096)`,
so on agnos every directory visited still burns 4 KB that is never returned —
which compounds under `-T` on a deep tree. Known, recorded in
`docs/development/state.md`, and deliberately not bundled into the v1.3.2
patch cut because it is an agnos behavior change that wants its own test pass.

**When to use which**: `alloc()` for anything whose lifetime is the run (the
entries vec, the decoration vecs, the parsed git index). `fl_alloc()` /
`fl_free()` — the freelist — for data with an individual lifetime. A stack
`var buf[N]` for scratch that dies at the end of the function, which is
almost always the right answer inside a loop. See
[001](001-var-buf-is-bytes.md) for how to size those.

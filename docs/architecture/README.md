# Architecture notes

Non-obvious constraints, quirks, and invariants that a reader cannot derive from the code alone. Numbered chronologically — never renumber.

Not decisions (those live in [`../adr/`](../adr/)) and not guides (those live in [`../guides/`](../guides/)). An item here describes *how the world is*, not *what we chose* or *how to do something*.

## Items

| Note | Invariant |
|---|---|
| [001 — `var buf[N]` is bytes, not slots](001-var-buf-is-bytes.md) | The language guide says slots; `cycc` gives bytes. Undersizing corrupts adjacent rodata silently. Covers the recurring `144` / `4096` / `8` literals and what each actually is. |
| [002 — the agnos FS ABI split](002-agnos-fs-abi-split.md) | Four ways AGNOS's filesystem ABI differs in *shape* from Linux, all hidden behind `walk.cyr`'s wrappers — including why agnos `sys_readdir` must **not** replace the `getdents` enumerator. |
| [003 — allocation lifetime model](003-allocation-lifetime-model.md) | `alloc()` is a bump allocator with no free; the process is the deallocator. Why that is sound here, and where it stops being sound. |

Populated at v1.3.2 during the P(-1) sweep. The section had read "_Empty_"
since v0.1.0 while all three invariants were live in the code — the second and
third had already cost real bugs.

Add a numbered entry (`00N-kebab-case-title.md`) the first time the code has a
non-obvious invariant a reader can't derive. Do not write entries for
decisions — those are ADRs.

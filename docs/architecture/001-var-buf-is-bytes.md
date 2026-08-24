# 001 — `var buf[N]` allocates N **bytes**, and three magic numbers depend on it

**Applies to**: every `var`-declared buffer in `src/` (19 sites as of v1.3.2).

The Cyrius language guide describes `var buf[N]` as N *slots*. In `cycc` it is
N **bytes**. Every stack buffer in darshini is sized on the byte reading, and
getting it wrong does not fail loudly — it silently writes into adjacent
rodata. This was caught at M1 when an undersized stat buffer made a `"\n"`
literal in the same translation unit start emitting `0xed`.

Three sizes recur, and each is a real ABI or kernel constant rather than a
round number someone liked:

| Literal | Why | Sites |
|---|---|---|
| `144` | `struct stat` on x86_64 Linux. Every `sys_stat` / `lstat_path` probe buffer. | `walk.cyr`, `color.cyr`, `long.cyr`, `tree.cyr`, `git.cyr` |
| `4096` | `PATH_MAX`. `PATH_BUF_SIZE` in `color.cyr`, and the `getcwd` buffer in `git.cyr`. | `color.cyr`, `git.cyr` |
| `8` | One `i64` out-param slot, or the four `u16` fields of `winsize`. | `columns.cyr`, `tree.cyr` |

The `144` is *not* the same on every target — the `STAT_*` field offsets come
from the stdlib per-target, so field reads are portable, but the buffer size
literal is not. See [002](002-agnos-fs-abi-split.md).

**What to do when adding a buffer**: size it in bytes against the actual
maximum the consumer can write, not the expected one. A `?`-placeholder path
that renders wrong is a bug; a buffer that is one byte short is a
memory-safety defect that will present as unrelated corruption somewhere else
in the binary.

`_path_join_into` in `color.cyr` is the cautionary example: from v1.1.2 to
v1.3.1 it `memcpy`'d `dir + '/' + name + NUL` into a fixed `alloc(4096)` with
no capacity check at all. A listing path near `PATH_MAX` holding a `NAME_MAX`
entry needs 4353 bytes. Measured overflow on a 3915-byte directory holding a
255-byte name: 76 bytes past the end of the allocation, reachable from `argv`,
with no crash — the bump allocator's slack absorbed it, which is exactly why it
survived three minor releases. Bounded in v1.3.2.

Related: [`feedback-cyrius-var-buf-bytes`] in the maintainer's notes, and the
`var buf[N]` audit table in
[`../audit/2026-05-23-audit.md`](../audit/2026-05-23-audit.md).

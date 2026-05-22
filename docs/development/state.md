# darshini — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.3.0** — M2 (`-l` long format + `-h` human-readable sizes)
shipped 2026-05-22. M1 (basic listing) shipped earlier same day
as v0.2.0. Scaffolded as **0.1.0** on 2026-05-19 via
`cyrius init darshini`.

## Toolchain

- **Cyrius pin**: `6.0.0` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`darshini`). Single-shot CLI: walk a directory, render entries
to stdout, exit. Pipe-aware (plain output on non-TTY).

## Source

- `src/main.cyr` — entry point + argv flag parser + dispatch
- `src/walk.cyr` — `classify_path`, `check_dir_readable`, `list_dir`,
  `lstat_path`, `ModeBit` enum (POSIX S_IF*/S_I* constants)
- `src/render.cyr` — `lower_byte`, `str_lt_ci`, `sort_entries`,
  `print_entries`, `format_perms`, `format_size_decimal`,
  `format_size_human`, `format_mtime`
- `src/long.cyr` — long-format orchestrator (two-pass:
  collect-stat-then-emit-aligned)

M3+ onward fills:

- `src/render.cyr` grows multi-column auto-layout + TTY width
  probe at M3
- `src/color.cyr` — darshana ANSI routing (M4)
- `src/icons.cyr` — icon-mapping loader (M5)
- `src/tree.cyr` — recursive box-drawn rendering (M6)
- `src/git.cyr` — `.git/`-direct status column (M7)
- `src/mime.cyr` — magic-bytes mime detector (M8)

## Features

| Feature | Milestone | Status |
|---------|-----------|--------|
| Basic listing | M1 | **shipped** (v0.2.0) |
| `-l` long format + `-h` human sizes | M2 | **shipped** (v0.3.0) |
| Multi-column auto-layout, `-1` | M3 | pending |
| Color via darshana | M4 | pending |
| Icons via CYML mapping | M5 | pending |
| `-T` / `--tree` | M6 | pending |
| `--git` status column | M7 | pending |
| `--mime` recognition | M8 | pending |

## Tests

- `tests/darshini.tcyr` — 74 assertions across M1's pure-function
  surface + the fs probes against the project tree + M2 column
  formatters (perms / size / mtime)
- `tests/darshini.bcyr` — benchmark stub
- `tests/darshini.fcyr` — fuzz stub

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, args, fs,
  chrono, assert, bench. `args` + `fs` added at M1 (argv access
  + getdents64-backed dir_list); `chrono` added at M2 for
  `epoch_to_date` + the 2-digit / 4-digit formatting helpers.

M4 adds `[deps.darshana]` for ANSI / color primitives.

## Consumers

_None yet._ darshini is end-user-facing; "consumers" are user
shell sessions and the maintainer's `ls` alias.

## Next

See [`roadmap.md`](roadmap.md). Next ship is M3 (multi-column
auto-layout + `-1` force-single-column), targeting v0.4.0.
TTY-width detection via `ioctl(TIOCGWINSZ)` with a 80-col
fallback. Pipe-aware single-column under non-TTY stdout becomes
explicit at this milestone (until M3 it's incidental — print
order is one per line by default).

## Known gotchas

- **`var buf[N]` is N bytes, not N slots.** Cyrius 6.0.1 contradicts
  the language guide here. `classify_path` sizes its stat buffer
  as `var buf[144]` (= `STAT_BUFSZ`). Misreading the guide and
  writing `var buf[18]` silently corrupts adjacent rodata
  (caught at M1 when `"\n"` literal in the same TU started
  emitting 0xed). Audit any new stat / read syscall buffer
  sizing against actual byte width.
- **mtime is UTC, not local time** under `-l`. The v1.0 contract
  picks locale-free + stable over matching `ls -l`'s local-time
  default; users comparing the two side-by-side will see their
  UTC-offset as a discrepancy. Documented in the M2 CHANGELOG.
- **lstat is Linux x86_64 only.** `walk.cyr`'s `lstat_path` uses
  bare syscall 6; aarch64 needs the at-family detour through
  `newfstatat`. Cross-compile to aarch64 will need the same
  arch-dispatch pattern that the stdlib's syscalls peers already
  use — follow-up before any non-x86 release.

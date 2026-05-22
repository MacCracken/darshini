# darshini — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.4.0** — M3 (multi-column auto-layout + `-1` force-single)
shipped 2026-05-22, same day as M1 (v0.2.0) and M2 (v0.3.0).
Scaffolded as **0.1.0** on 2026-05-19 via `cyrius init darshini`.

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
- `src/columns.cyr` — `term_width` (ioctl TIOCGWINSZ),
  `pick_cols`, `render_columns` (vertical-then-horizontal)

M4+ onward fills:

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
| Multi-column auto-layout, `-1` | M3 | **shipped** (v0.4.0) |
| Color via darshana | M4 | pending |
| Icons via CYML mapping | M5 | pending |
| `-T` / `--tree` | M6 | pending |
| `--git` status column | M7 | pending |
| `--mime` recognition | M8 | pending |

## Tests

- `tests/darshini.tcyr` — 93 assertions across M1 (lower_byte,
  str_lt_ci, sort_entries, classify_path, check_dir_readable),
  M2 (format_perms, format_size_decimal, format_size_human,
  format_mtime), and M3 (pick_cols, _columns_total_width)
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

See [`roadmap.md`](roadmap.md). Next ship is M4 (color via
darshana), targeting v0.5.0. Wires up the first `[deps.darshana]`
external dependency; per-entry color by file type (dir,
executable, symlink, broken symlink, regular file); TTY auto-
detect (no color on pipe — already implemented for column
layout, the same gate applies); `--no-color` flag to force-off.
First ADR (`docs/adr/0001-color-scheme.md`) lands here.

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
- **Linux x86_64 only through v1.0.** Per roadmap "Out of scope":
  non-x86 / non-Linux is **post-v1**. Specific x86_64 dependencies
  to revisit when platform work opens: (a) `walk.cyr`'s
  `lstat_path` uses bare syscall 6 — aarch64 needs an at-family
  detour through `newfstatat`; (b) `columns.cyr`'s
  `TIOCGWINSZ_LINUX = 0x5413` is Linux-only (BSDs use a
  different request number); (c) `walk.cyr` reads `st_mode` at
  offset 24 per the x86_64 stat layout. All three already use
  the `Stat` enum or local constants, so the arch-dispatch
  pattern is clear when the time comes.

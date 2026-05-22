# darshini — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.6.0** — M5 (icons via CYML mapping) shipped 2026-05-22.
Same day as M1 (v0.2.0), M2 (v0.3.0), M3 (v0.4.0), M4 (v0.5.0).
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
- `src/color.cyr` — `color_for_mode` picker, `compute_decor`
  fs-side parallel-vec builder (colors + icons in one lstat
  pass), `emit_decorated` write wrap
- `src/icons.cyr` — compile-baked icon picker (`icon_for_entry`,
  `icon_display_width`) mirroring `icons/default.cyml`

M6+ onward fills:

- `src/tree.cyr` — recursive box-drawn rendering (M6)
- `src/git.cyr` — `.git/`-direct status column (M7)
- `src/mime.cyr` — magic-bytes mime detector (M8)

## Features

| Feature | Milestone | Status |
|---------|-----------|--------|
| Basic listing | M1 | **shipped** (v0.2.0) |
| `-l` long format + `-h` human sizes | M2 | **shipped** (v0.3.0) |
| Multi-column auto-layout, `-1` | M3 | **shipped** (v0.4.0) |
| Color via darshana | M4 | **shipped** (v0.5.0) |
| Icons via CYML mapping | M5 | **shipped** (v0.6.0) |
| `-T` / `--tree` | M6 | pending |
| `--git` status column | M7 | pending |
| `--mime` recognition | M8 | pending |

## Tests

- `tests/darshini.tcyr` — 132 assertions across M1 (lower_byte,
  str_lt_ci, sort_entries, classify_path, check_dir_readable),
  M2 (format_perms, format_size_decimal, format_size_human,
  format_mtime), M3 (pick_cols, _columns_total_width), M4
  (color_for_mode), and M5 (icon_display_width, icon_for_entry,
  pick_cols + icon_width)
- `tests/darshini.bcyr` — benchmark stub
- `tests/darshini.fcyr` — fuzz stub

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, args, fs,
  chrono, assert, bench. `args` + `fs` added at M1 (argv access
  + getdents64-backed dir_list); `chrono` added at M2 for
  `epoch_to_date` + the 2-digit / 4-digit formatting helpers.
- `[deps.darshana]` (git, tag 0.5.3) — TTY/ANSI/cursor primitives.
  First external dep; landed at M4 for the color escapes. All
  raw ANSI routes through darshana's `tty_sgr` / `tty_sgr_reset`
  per CLAUDE.md.

## Consumers

_None yet._ darshini is end-user-facing; "consumers" are user
shell sessions and the maintainer's `ls` alias.

## Next

See [`roadmap.md`](roadmap.md). Next ship is M6 (`-T` /
`--tree` recursive display), targeting v0.7.0. Box-drawing
characters for the connectors; `--level N` to cap depth;
reuses M2's row format per entry. Tests: nested dirs,
symlink-to-dir (don't recurse by default; explicit flag to
follow).

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

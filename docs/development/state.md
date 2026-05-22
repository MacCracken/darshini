# darshini — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.2.0** — M1 (directory walk + basic listing) shipped 2026-05-22.
Scaffolded as **0.1.0** on 2026-05-19 via `cyrius init darshini`.

## Toolchain

- **Cyrius pin**: `6.0.0` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`darshini`). Single-shot CLI: walk a directory, render entries
to stdout, exit. Pipe-aware (plain output on non-TTY).

## Source

- `src/main.cyr` — entry point + dispatch (argv → classify → list/echo/err)
- `src/walk.cyr` — `classify_path`, `check_dir_readable`, `list_dir`
- `src/render.cyr` — `lower_byte`, `str_lt_ci`, `sort_entries`, `print_entries`

M2+ onward fills:

- `src/walk.cyr` grows per-entry stat (mode, size, mtime, owner) at M2
- `src/render.cyr` grows long-format row formatting + column layout at M2 / M3
- `src/color.cyr` — darshana ANSI routing (M4)
- `src/icons.cyr` — icon-mapping loader (M5)
- `src/tree.cyr` — recursive box-drawn rendering (M6)
- `src/git.cyr` — `.git/`-direct status column (M7)
- `src/mime.cyr` — magic-bytes mime detector (M8)

## Features

| Feature | Milestone | Status |
|---------|-----------|--------|
| Basic listing | M1 | **shipped** (v0.2.0) |
| `-l` long format + `-h` human sizes | M2 | pending |
| Multi-column auto-layout, `-1` | M3 | pending |
| Color via darshana | M4 | pending |
| Icons via CYML mapping | M5 | pending |
| `-T` / `--tree` | M6 | pending |
| `--git` status column | M7 | pending |
| `--mime` recognition | M8 | pending |

## Tests

- `tests/darshini.tcyr` — 30 assertions across M1's pure-function
  surface + the fs probes against the project tree
- `tests/darshini.bcyr` — benchmark stub
- `tests/darshini.fcyr` — fuzz stub

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, args, fs,
  assert, bench (`args` + `fs` added at M1 for argv access +
  getdents64-backed dir_list)

M4 adds `[deps.darshana]` for ANSI / color primitives.

## Consumers

_None yet._ darshini is end-user-facing; "consumers" are user
shell sessions and the maintainer's `ls` alias.

## Next

See [`roadmap.md`](roadmap.md). Next ship is M2 (`-l` long format
+ `-h` human-readable sizes), targeting v0.3.0. Builds on M1's
`classify_path` by stashing the full stat buf and surfacing
permissions / size / mtime through `render.cyr`.

## Known gotchas

- **`var buf[N]` is N bytes, not N slots.** Cyrius 6.0.1 contradicts
  the language guide here. `classify_path` sizes its stat buffer
  as `var buf[144]` (= `STAT_BUFSZ`). Misreading the guide and
  writing `var buf[18]` silently corrupts adjacent rodata
  (caught at M1 when `"\n"` literal in the same TU started
  emitting 0xed). Audit any new stat / read syscall buffer
  sizing against actual byte width.

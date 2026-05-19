# darshini — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.1.0** — scaffolded 2026-05-19 via `cyrius init darshini`. No releases yet.

## Toolchain

- **Cyrius pin**: `6.0.0` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`darshini`). Single-shot CLI: walk a directory, render entries
to stdout, exit. Pipe-aware (plain output on non-TTY).

## Source

- `src/main.cyr` — entry point; currently prints scaffold version line

M1+ onward fills:

- `src/walk.cyr` — directory walking + per-entry stat
- `src/render.cyr` — line / column / tree formatting
- `src/color.cyr` — darshana ANSI routing (M4)
- `src/icons.cyr` — icon-mapping loader (M5)
- `src/tree.cyr` — recursive box-drawn rendering (M6)
- `src/git.cyr` — `.git/`-direct status column (M7)
- `src/mime.cyr` — magic-bytes mime detector (M8)

## Features

_None shipped yet. Targets through v1.0:_

| Feature | Milestone | Status |
|---------|-----------|--------|
| Basic listing | M1 | pending |
| `-l` long format + `-h` human sizes | M2 | pending |
| Multi-column auto-layout, `-1` | M3 | pending |
| Color via darshana | M4 | pending |
| Icons via CYML mapping | M5 | pending |
| `-T` / `--tree` | M6 | pending |
| `--git` status column | M7 | pending |
| `--mime` recognition | M8 | pending |

## Tests

- `tests/darshini.tcyr` — primary suite (currently empty per cyrius init defaults)
- `tests/darshini.bcyr` — benchmark stub
- `tests/darshini.fcyr` — fuzz stub

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, assert, bench

M4 adds `[deps.darshana]` for ANSI / color primitives.

## Consumers

_None yet._ darshini is end-user-facing; "consumers" are user
shell sessions and the maintainer's `ls` alias.

## Next

See [`roadmap.md`](roadmap.md). Next ship is M1 (directory walk + basic listing), targeting v0.2.0.

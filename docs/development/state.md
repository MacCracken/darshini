# darshini — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**1.0.0** — M10 (v1.0 freeze) shipped 2026-05-23. CLI flag
surface frozen per ADR 0001 / 0002 / 0003 / 0004. M9
(v0.9.1) shipped the audit + bench baseline + ADR 0004
back-fill earlier same day. M1–M8 (v0.2.0 → v0.9.0)
shipped 2026-05-22/23. Scaffolded as **0.1.0** on 2026-05-19
via `cyrius init darshini`.

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
- `src/tree.cyr` — `render_tree` + the depth-stack recursion;
  `_tree_prefix_buf` / `_tree_connector_buf` for testable
  byte-sequence helpers
- `src/git.cyr` — `.git/index` v2 parser + minimal
  `.gitignore` parser + `git_status_for` classifier
  (`.`/`M`/`?`/`!`). Single GitCtx loaded per listing.
- `src/mime.cyr` — `mime_for_entry` master + the
  inode/filename/ext/exec/magic precedence chain
  per ADR 0003. Compile-baked mapping mirroring
  `mime/default.cyml`.

M9+ onward fills:

- M9: P(-1) hardening + audit doc + bench baseline (pre-v1.0)

## Features

| Feature | Milestone | Status |
|---------|-----------|--------|
| Basic listing | M1 | **shipped** (v0.2.0) |
| `-l` long format + `-h` human sizes | M2 | **shipped** (v0.3.0) |
| Multi-column auto-layout, `-1` | M3 | **shipped** (v0.4.0) |
| Color via darshana | M4 | **shipped** (v0.5.0) |
| Icons via CYML mapping | M5 | **shipped** (v0.6.0) |
| `-T` / `--tree` | M6 | **shipped** (v0.7.0) |
| `--git` status column | M7 | **shipped** (v0.8.0) |
| `--mime` recognition | M8 | **shipped** (v0.9.0) |
| Pre-v1 audit + bench baseline | M9 | **shipped** (v0.9.1) |
| v1.0.0 freeze | M10 | **shipped** (v1.0.0) |

## Tests

- `tests/darshini.tcyr` — 233 assertions across M1 (lower_byte,
  str_lt_ci, sort_entries, classify_path, check_dir_readable),
  M2 (format_perms, format_size_decimal, format_size_human,
  format_mtime), M3 (pick_cols, _columns_total_width), M4
  (color_for_mode), M5 (icon_display_width, icon_for_entry,
  pick_cols + icon_width), M6 (_tree_connector_buf,
  _tree_prefix_buf, _parse_pos_int), and M7 (_be_u32 / _be_u16,
  _git_parse_index header, _git_match_one, _git_listing_rel)
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

v1.x maintenance + v1.1 enhancement backlog. From the
[2026-05-23 audit](../audit/2026-05-23-audit.md) Step 5
findings and the M10 release notes:

- **`sort_entries` merge-sort upgrade** — eliminates the
  O(N²) worst case (36 ms@1k reversed per the bench
  baseline). Worth doing when a user hits the case.
- **`git_status_for` hashmap** — linear-scan goes quadratic
  for repos > ~5k tracked files.
- **`-F` (classify) + `-d` (list-dir-as-self)** flags —
  surfaced by the maintainer's dotfile migration (would
  retire the remaining `eza` aliases `lfiles`, `llfiles`,
  `ldir`, `lldir`).
- **mtime localization** — keep UTC default; add an
  opt-in flag for local time per the M2 notes.
- **Platform support** — aarch64 Linux, then macOS / BSD /
  Windows. The arch-specific sites are already documented
  in this file's "Known gotchas" section.

Non-roadmap items remain non-breaking additions per the M10
freeze contract.

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

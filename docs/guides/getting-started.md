# Getting started with darshini

## Build

```sh
cyrius deps                                  # resolve stdlib + darshana
cyrius build src/main.cyr build/darshini     # compile
./build/darshini                              # list the current directory
cyrius test                                   # run tests/*.tcyr
cyrius bench                                 # run perf benches
```

`cyrius bench` auto-discovers `tests/darshini.bcyr` as of cycc
**6.4.78** (darshini picked this up at v1.3.1 with the 6.5.35 pin).
Before that it looked only in `benches/` and `tests/bcyr/` and
reported "No benchmarks found", which is why the older docs pass
`tests/darshini.bcyr` explicitly. The explicit form still works and
is what [`docs/benchmarks.md`](../benchmarks.md) captured.

## Install for daily use

```sh
cp build/darshini ~/.local/bin/
darshini --version       # confirm
```

See the README for the recommended zsh alias set
(`ll`, `l`, `lfiles`, `llfiles`, `ldir`, `lldir`).

## Source layout (v1.x)

| Module            | Owns |
|-------------------|------|
| `src/main.cyr`    | Entry, argv parsing, multi-path dispatch (`run_all`), per-path orchestration (`run`) |
| `src/cli.cyr`     | Pure argv helpers (`_arg_eq`, `_parse_pos_int`, `_long_flag_code`) — includable by the test suite |
| `src/walk.cyr`    | Buffered checked writer (`d_write` / `d_flush`), stat / open wrappers, `classify_path`, `check_dir_readable`, `list_dir_checked`, `d_basename`, `ModeBit` enum, `-F` classify indicator |
| `src/render.cyr`  | Pure formatters: `lower_byte`, `_str_cmp_ci` / `str_lt_ci` (the listing order), `sort_entries` (stdlib `vec_sort_by`), `print_entries`, `format_perms`/`size_*`/`mtime` |
| `src/columns.cyr` | TTY width probe (darshana `tty_winsize`), column-fit picker over written widths, `_columns_emit` (vertical-then-horizontal) |
| `src/long.cyr`    | Long-format orchestrator (two-pass for size + mime alignment), `render_long_one` for `-l <file>` |
| `src/tree.cyr`    | Recursive box-drawn rendering + depth-stack bookkeeping |
| `src/color.cyr`   | Color picker, `compute_decor` (single lstat pass → colors / icons / git / mime / classify vecs), `_path_join_into`, `emit_decorated`, the untrusted-text writers (`_write_name_bytes` / `_write_err_bytes` / `_name_display_len`) |
| `src/icons.cyr`   | Compile-baked icon lookup chain mirroring `icons/default.cyml` |
| `src/mime.cyr`    | Inode → filename → ext → exec → magic precedence chain mirroring `mime/default.cyml` |
| `src/ignore.cyr`  | git's `wildmatch` (port) and gitignore pattern parsing / matching — pure, no I/O (ADR 0005) |
| `src/gitcfg.cyr`  | A minimal git-config reader for `core.excludesFile`, `safe.directory`, `extensions.objectFormat` |
| `src/git.cyr`     | Repo discovery (physical path, `gitdir:` files, `commondir`), ownership, index v2–v4 parser, ignore precedence and inheritance, submodule `HEAD` status, `git_status_for*` |

Include order in `main.cyr` is dependency order, kept for the reader
(cycc resolves later definitions):
`walk → cli → icons → mime → ignore → gitcfg → git → color → render → columns → long → tree`.

## Adding a feature (v1.x non-breaking additions)

The v1.0 contract is **frozen** per ADR
[0001](../adr/0001-color-scheme.md) /
[0002](../adr/0002-icon-format.md) /
[0003](../adr/0003-mime-detection.md) /
[0004](../adr/0004-tree-mode.md).
v1.x additions must be **non-breaking**: new flags are fine;
changing the meaning, default state, or output bytes of any
existing flag is a 2.x change.

1. Identify the change kind:
   - New flag → v1.minor (e.g. `--my-feature`)
   - Internal perf or fix → v1.patch
   - Breaking → v2.0 (rare; needs separate ADR + roadmap)
2. Edit the appropriate `src/<module>.cyr`. If you change a
   public fn signature, walk every caller AND every test that
   calls it — Cyrius leaves unfilled arg slots as register
   garbage, so under-passing silently corrupts state.
3. Bump `VERSION` (and the CHANGELOG header). Since v1.4.1
   `--version` prints `CYRIUS_PKG_VERSION`, which `cyrius build`
   takes from `cyrius.cyml` → `VERSION`; there is no literal to
   keep in step, and CI fails if one comes back.
4. Update tests in `tests/darshini.tcyr` for any pure helper
   you added. If output changed on purpose, regenerate the golden
   examples (`sh tests/examples.sh > docs/examples/README.md`);
   CI fails on a stale copy. An icon or mime edit goes in both the
   CYML and `src/` — CI's `tests/table-drift.sh` checks they agree. Filesystem effects are covered by CI smokes
   (see `.github/workflows/ci.yml`).
5. If the feature touches color or cursor positioning, route
   through darshana — color is composed with `tty_sgr_buf` /
   `tty_sgr_reset_buf` inside `emit_decorated` (`src/color.cyr`).
   **No raw ANSI in darshini source.** Per CLAUDE.md hard rule.
   Anything you print that darshini did not write — a filename, a
   path argument, a path in an error message — goes through
   `_write_name_bytes` (stdout) or `_write_err_bytes` (stderr),
   which apply darshana's `tty_sanitize_buf` on a terminal.
6. CHANGELOG entry. Add a `Breaking` section only if you're
   doing a 2.x change.

## Adding an icon

1. Edit `icons/default.cyml` (the spec).
2. Edit `src/icons.cyr` to mirror (compile-baked at v1.x).
3. CHANGELOG entry under `Added`.

The two files must stay in sync — this is human-enforced at PR
review. A CI gate that parses the CYML and verifies coverage
is a v2 candidate. See [ADR 0002](../adr/0002-icon-format.md).

## Adding a mime type

Same dance as icons: `mime/default.cyml` (spec) +
`src/mime.cyr` (compile-baked). See
[ADR 0003](../adr/0003-mime-detection.md).

## Pipe-awareness

darshini is pipe-aware by default. On a TTY: multi-column,
colored, icons. On a pipe (`darshini | cat`,
`darshini | grep ...`): one entry per line, no color, no
icons — same as minimal `ls`. **Never surprise a script
consumer.** This is a CLAUDE.md hard rule.

## Adding an ADR

If your change introduces a non-obvious design choice, add an
ADR per [`../adr/template.md`](../adr/template.md). Numbered
chronologically; never renumber. Current ADRs:

- [0001 color scheme](../adr/0001-color-scheme.md)
- [0002 icon format](../adr/0002-icon-format.md)
- [0003 mime detection](../adr/0003-mime-detection.md)
- [0004 tree mode](../adr/0004-tree-mode.md)

## Running the audit

The pre-v1.0 audit lives at
[`../audit/2026-05-23-audit.md`](../audit/2026-05-23-audit.md).
For your own audit pass:

```sh
cyrius build src/main.cyr build/darshini     # cleanliness check
cyrius test                                   # full assertion sweep
for f in src/*.cyr; do cyrius lint "$f"; done # style + bugs
cyrius vet src/main.cyr                       # dep audit
cyrius bench tests/darshini.bcyr              # perf snapshot
```

Compare bench numbers against `docs/benchmarks.md` to spot
regressions.

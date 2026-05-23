# Getting started with darshini

## Build

```sh
cyrius deps                                  # resolve stdlib + darshana
cyrius build src/main.cyr build/darshini     # compile
./build/darshini                              # list the current directory
cyrius test                                   # run tests/*.tcyr
cyrius bench tests/darshini.bcyr              # run perf benches
```

Note `cyrius bench` won't auto-discover `tests/*.bcyr` — pass
the explicit path.

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
| `src/walk.cyr`    | `classify_path`, `check_dir_readable`, `list_dir`, `lstat_path`, `ModeBit` enum, `-F` classify indicator |
| `src/render.cyr`  | Pure formatters: `lower_byte`, `str_lt_ci`, hybrid merge-sort `sort_entries`, `print_entries`, `format_perms`/`size_*`/`mtime` |
| `src/columns.cyr` | TTY width probe, column-fit picker, `_columns_emit` (vertical-then-horizontal) |
| `src/long.cyr`    | Long-format orchestrator (two-pass for size + mime alignment), `render_long_one` for `-l <file>` |
| `src/tree.cyr`    | Recursive box-drawn rendering + depth-stack bookkeeping |
| `src/color.cyr`   | Color picker, `compute_decor` (single lstat pass → colors / icons / git / mime / classify vecs), `_path_join_into`, `emit_decorated` |
| `src/icons.cyr`   | Compile-baked icon lookup chain mirroring `icons/default.cyml` |
| `src/mime.cyr`    | Inode → filename → ext → exec → magic precedence chain mirroring `mime/default.cyml` |
| `src/git.cyr`     | `.git/index` v2 parser, minimal `.gitignore` matcher, hashmap-backed `git_status_for` |

Include order in `main.cyr` matters for clean LSP:
`walk → icons → mime → git → color → render → columns → long → tree`.

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
3. Update `--version` string in `src/main.cyr`'s
   `_darshini_version_str()` in lockstep with `VERSION`. CI
   smoke pins the exact string.
4. Update tests in `tests/darshini.tcyr` for any pure helper
   you added. Filesystem effects are covered by CI smokes
   (see `.github/workflows/ci.yml`).
5. If the feature touches color or cursor positioning, route
   through darshana's `tty_sgr` / `tty_sgr_reset`. **No raw
   ANSI in darshini source.** Per CLAUDE.md hard rule.
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

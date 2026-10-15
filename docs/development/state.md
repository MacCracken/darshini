# darshini — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). History lives in the
> [CHANGELOG](../../CHANGELOG.md); the forward plan in
> [`roadmap.md`](roadmap.md).

## Version

**1.4.2** — internals and CI, shipped 2026-10-15. Patch bump; no output
byte changes on any target (A/B: 304 / 304 captures identical to 1.4.1,
plus ~230k lines of real trees). Toolchain and darshana unchanged
(cyrius 6.7.9, darshana 1.3.0).

- `sort_entries` is the stdlib's `vec_sort_by` (introsort, no
  allocation) instead of darshini's merge sort — unblocked by 1.4.1's
  total order. Already-sorted 1k entries 499 → 87 µs; `-T /usr/share`
  peak RSS 24.8 → 22.7 MB (no scratch vec per directory).
- CI now *runs* the cross targets: aarch64 suite + fuzz + a 21-mode
  output-parity matrix against x86_64 under qemu; agnos suite + fuzz
  under a pinned, checksum-verified mirshi release. The agnos suite is
  401 / 401 — its two errno assertions now assert agnos's flat `-1`.
- New CI gates: icon / mime CYML vs compiled tables
  (`tests/table-drift.sh`), golden examples (`tests/examples.sh`), and a
  shared parity matrix (`tests/parity.sh`) for the DCE and aarch64 gates.

Prior: **1.4.1** (2026-10-15) — audit and repair sweep: hostile-mtime
injection fixed, `--git` corrected (file args, `..`, index v3/v4/SHA-256,
u32 compare, submodules declined), `-F` / `--` / tree-error / write-error
fixes, buffered stdout. Report:
[`../audit/2026-10-15-audit.md`](../audit/2026-10-15-audit.md). Earlier
releases: see the CHANGELOG.

## Toolchain

- **Cyrius pin**: `6.7.9` (in `cyrius.cyml [package].cyrius`)
- `lib/` is generated: `rm -rf lib/ && cyrius deps` (33 files at
  6.7.9 — the declared `[deps].stdlib` footprint, closed).

## Shape

Binary (`darshini`). Single-shot CLI: walk a directory, render entries
to stdout, exit. Pipe-aware (plain output on non-TTY).

## Source

- `src/main.cyr` — entry point, argv parser (`parse_cli`), per-path
  dispatch (`run` / `run_all`), help / usage text
- `src/cli.cyr` — pure argv helpers (`_arg_eq`, `_parse_pos_int`,
  `_long_flag_code`); split out at v1.4.1 so the suite can include them
- `src/walk.cyr` — the buffered checked writer (`d_write` / `d_flush` /
  `_d_write_raw`), the stat / open wrappers (`d_stat`, `d_lstat`,
  `d_open_probe` / `_data` / `_dir`, `d_fd_regular_size`),
  `classify_path`, `check_dir_readable`, `list_dir_checked` (stdlib
  `dir_list_checked`, all targets), `d_basename`, `ModeBit` enum
- `src/render.cyr` — `_str_cmp_ci` / `str_lt_ci` (case-insensitive,
  raw-byte tiebreak: a strict total order), `sort_entries` (stdlib
  `vec_sort_by`), `print_entries`, `format_perms` / `_size_*` / `_mtime`
- `src/long.cyr` — `-l` (two-pass: collect, then emit aligned) and
  `render_long_one` for a single path
- `src/columns.cyr` — `term_width` (darshana `tty_winsize`; 0 on agnos
  by decision), `pick_cols`, `render_columns`
- `src/color.cyr` — `color_for_mode`, `compute_decor` (one lstat pass
  for every decoration), `emit_decorated`, the untrusted-text writers
  (`_write_name_bytes` / `_write_err_bytes` over darshana's
  `tty_sanitize_buf`), `emit_error` / `emit_dir_error`
- `src/icons.cyr` — compile-baked icon table mirroring
  `icons/default.cyml`
- `src/tree.cyr` — `-T`: depth-stack recursion, read-error reporting
- `src/git.cyr` — physical-path repo discovery, `.git/index` v2/v3/v4
  (SHA-1 / SHA-256) parser, ignore-subset parser, status classifier,
  per-repo parse cache, directory prefix set
- `src/mime.cyr` — inode / filename / extension / exec / magic chain
  (ADR 0003), compile-baked table mirroring `mime/default.cyml`

## Features

| Feature | Since |
|---------|-------|
| Listing, `-l` / `-h`, multi-column / `-1`, color, icons, `-T` / `--level`, `--git`, `--mime` | M1–M8 (v0.2–v0.9) |
| v1.0 freeze | v1.0.0 |
| `--help` / `--version` / `-F` / `-d`; multi-path | v1.1.0 / v1.1.1 |
| AGNOS target | v1.3.0 |
| Checked writes (write error → exit 1) | v1.3.3 |
| Terminal sanitization of every untrusted name / path | v1.3.2, complete v1.4.0 |
| `--` end of options; `-F` on path arguments; read errors reported | v1.4.1 |

Supported targets: **Linux x86_64, AGNOS**. The aarch64 build matches
x86_64 byte-for-byte (304 / 304 A/B captures; CI checks a 21-mode
matrix on every push since v1.4.2) but is not declared supported
(roadmap 1.7.0).

## Tests

- `tests/darshini.tcyr` — **401** assertions (v1.4.2; 400 at v1.4.1,
  301 at v1.4.0). v1.4.2 added a randomized differential check of the
  stdlib sort against an insertion-sort reference.
  Pure helpers per module, the sanitizer rule, column math, the chrono
  layout pin, and since v1.4.1: the sort tiebreak and merge path,
  `classify_indicator`, the mtime bound, P / E sizes, `--level` bounds,
  `_long_flag_code`, `d_basename`, hand-built index images (v2, v3
  extended flags, v4 prefix compression, long names, SHA-256, misframing),
  `_git_oid_len`, every `--git` status outcome including the u32 compare
  and `git_status_for_root`, the hardened magic probe. Cross-targets,
  both run by CI since v1.4.2: aarch64 under `qemu-aarch64` 401 / 401;
  agnos under mirshi 401 / 401 (its errno assertions expect agnos's flat
  `-1`).
- `tests/darshini.fcyr` — 6 fuzz targets with named invariants:
  `.git/index` (v2/v3/v4, SHA-1/SHA-256 framing), `.gitignore` (CRLF
  differential), magic bytes, `_path_join_into` (canary), the name
  sanitizer, the mtime formatter (v1.4.1, mutation-validated). Runs in
  CI since v1.4.1.
- `tests/darshini.bcyr` — micro-benchmarks (`cyrius bench`).
- `tests/parity.sh` (two builds, 21 modes, pipe + PTY),
  `tests/table-drift.sh` (CYML vs compiled tables),
  `tests/examples.sh` (regenerates the golden `docs/examples/README.md`)
  — CI helpers, runnable locally from the repo root.
- CI (`.github/workflows/ci.yml`) — build, golden examples, strict lint,
  tests, fuzz, agnos (mirshi) + aarch64 (qemu) suite / fuzz runs and
  aarch64 output parity, 22 smoke gates, DCE parity, security scan,
  table drift, docs / version consistency.

## Dependencies

- stdlib — string, fmt, alloc, io, vec, str, syscalls, args, fs,
  chrono, hashmap, assert, bench (`cyrius.cyml [deps].stdlib`).
- `[deps.darshana]` (git, tag **1.3.0**; needs cyrius ≥ 6.7.2) — used:
  `tty_sgr_buf` / `tty_sgr_reset_buf` + `TTY_FG_*`, `tty_winsize`,
  `tty_isatty`, `tty_sanitize_buf` / `tty_has_ctl` +
  `TTY_SANITIZE_UTF8`. API frozen since 1.0.0 (additive only).

## Consumers

_None._ darshini is end-user-facing; "consumers" are user shell
sessions and the maintainer's `ls` alias.

## Next

See [`roadmap.md`](roadmap.md): 1.5.0 (`--git` accuracy, ADR 0005),
1.6.0 (display correctness), 1.7.0 (platforms).

## Known gotchas

- **`var buf[N]` is N bytes, not N slots** (the language guide is wrong
  here). Size every stack buffer against what the consumer can write.
  [`../architecture/001-var-buf-is-bytes.md`](../architecture/001-var-buf-is-bytes.md).
- **stdout is buffered** (v1.4.1). Everything bound for fd 1 must go
  through `d_write`; a bare `sys_write(1, …)` would land out of order.
  stderr writes flush stdout first, `main()` flushes before the exit
  check, and a harness that writes through `d_write` (the fuzz target)
  must call `d_flush()` before exiting.
- **Untrusted text has exactly two writers**: `_write_name_bytes`
  (stdout) and `_write_err_bytes` (stderr) in `color.cyr`. Anything
  darshini prints that it did not author goes through one of them.
  Metadata is untrusted too — `format_mtime` bounds the year for that
  reason.
- **mtime is UTC**, not local time (the v1.0 locale-free contract).
- **AGNOS terminal detection is console-wide**: `term_width` returns 0
  there (no decoration even on the console), while sanitization keys on
  `tty_isatty` and is on whenever the console is up. Opposite defaults,
  each failing safe. agnos also has no `getcwd` (`--git` needs an
  absolute path), a stub `fstat`, and no `lstat` wired yet
  ([`../architecture/002-agnos-fs-abi-split.md`](../architecture/002-agnos-fs-abi-split.md)).
- **`format_mtime` reads chrono's `DateTime` by named offset**
  (`DT_YEAR`…), pinned by assertions against the `dt_*` accessors.
  Migrating to the accessors was measured and rejected (each re-runs
  `epoch_to_date` with a fresh allocation).
- **Never swap the agnos directory read onto `sys_readdir` (#81)**: its
  64-byte records cap names at 63 bytes. The stdlib's `dir_list_checked`
  uses getdents (#29), which is what darshini wants.
- **Include order is convention, not a compiler requirement.** cycc
  6.7.9 resolves a call to a function defined later — in the same file
  or a later include (probed at v1.4.1); older comments in the tree
  claimed otherwise. `main.cyr` keeps dependency order for readability.
  The compiler does reject an arity mismatch, so a signature change
  fails the build at every stale call site.
- **The stdlib has a `path_basename`** that keeps trailing slashes;
  darshini's is `d_basename`.

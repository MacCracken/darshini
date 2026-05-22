# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.3.0] — M2: `-l` long format + `-h` human-readable sizes

### Added
- `-l` / `--long`: long-format rows — `permissions size mtime name`,
  size right-aligned within the listing's max-size width.
- `-h` / `--human`: IEC-style 1024-based size buckets — `X.YK`,
  `X.YM`, `X.YG`, `X.YT`. Sub-1K stays plain decimal. Modifier
  only; without `-l` it's a no-op (no size column shown anyway,
  matching `ls -h` semantics).
- Bundled short flags: `-lh` and `-hl` both work.
- `-l <file>`: under `-l`, a non-directory path renders as a
  single long row (matching `ls -l <file>` shape) instead of
  echoing the bare path.
- `src/long.cyr` — long-format orchestrator. Two-pass: collect
  per-row stat + size-string, then emit with size column
  right-aligned to the listing-wide max. Uses lstat (not stat)
  so symlinks render as themselves rather than their targets.
- `src/render.cyr` — adds `format_perms` (10-byte ls -l shape,
  including setuid/setgid/sticky upper+lower variants),
  `format_size_decimal`, `format_size_human` (decimal +
  IEC 1024-based), `format_mtime` (`YYYY-MM-DD HH:MM`, UTC).
- `src/walk.cyr` — adds `lstat_path` (bare syscall 6, no follow)
  and the `ModeBit` enum (POSIX `S_IF*` / `S_I*` constants).
- `cyrius.cyml` [deps].stdlib gains `chrono` (auto-included).
- Tests: 44 new assertions across `format_perms`,
  `format_size_decimal`, `format_size_human`, `format_mtime`.
  Total now 74/74.

### Notes
- Mtime is **UTC**, not local — matches the v1.0 contract
  ("locale-free, stable"). `ls -l` shows local time so darshini's
  output may differ by your tz offset. Documenting; not changing.
- Setuid / setgid / sticky bits render with the standard
  upper/lower convention: `s`/`S` (setuid + x / no x), same
  for setgid, `t`/`T` for sticky.
- Stat-failed rows (broken symlinks etc.) render with `?`
  placeholders so column alignment survives.
- M2 is Linux x86_64 only — `lstat_path` uses syscall 6 directly
  (no portable wrapper in stdlib yet). aarch64 dispatch needs an
  at-family detour through `newfstatat` — follow-up.
- M2 doesn't yet render symlink targets (`-> target` tail). That
  pairs with the symlink-display ADR work planned alongside
  M6 / M7.

## [0.2.0] — M1: directory walk + basic listing

### Added
- `darshini` lists the current directory, one entry per line, sorted
  case-insensitively. Acceptance for [M1 in the roadmap](docs/development/roadmap.md).
- `darshini <path>` — lists `<path>` if it's a directory; echoes
  the path if it's a regular file (matches `ls FILE` semantics).
- Error reporting on stat failure: `darshini: <path>: <reason>` to
  stderr, exit 1. Reasons surfaced separately: `no such file or
  directory` (ENOENT), `permission denied` (EACCES), `cannot stat`
  (everything else). `permission denied` on a stat-able but
  unreadable directory is surfaced via an explicit open probe in
  `check_dir_readable` because `dir_list` swallows open failures.
- `src/render.cyr` — display primitives: `lower_byte`,
  `str_lt_ci`, `sort_entries` (in-place insertion sort over
  vec<Str>), `print_entries`.
- `src/walk.cyr` — filesystem primitives: `classify_path`
  (sys_stat-based dir/non-dir/errno discriminator),
  `check_dir_readable` (sys_open probe), `list_dir` (dir_list wrap).
- `tests/darshini.tcyr` — 30 assertions across `lower_byte`,
  `str_lt_ci`, `sort_entries`, `classify_path`, `check_dir_readable`.
- `cyrius.cyml` [deps].stdlib gains `args` + `fs` (auto-included).

### Notes
- M1 is Linux x86_64 only — `classify_path` uses the x86_64 stat
  struct layout (144 bytes, `st_mode` at +24); aarch64 dispatch
  follows in a later cycle through the existing `Stat` enum.
- `var buf[N]` in Cyrius 6.0.x allocates N **bytes**, not N i64
  slots (the language guide is misleading; the bisect cost an
  afternoon — feedback memory filed). `classify_path` sizes its
  stat buffer as `var buf[144]` per `STAT_BUFSZ`.
- No darshana / colors / icons yet — those land at M4 / M5.

## [0.1.0]

### Added
- Initial project scaffold

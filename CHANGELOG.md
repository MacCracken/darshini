# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.7.0] — M6: tree mode (`-T` / `--tree`)

### Added
- `-T` / `--tree`: recursive box-drawn display.
  `tree(1)`-style connectors: `├──` for non-last siblings,
  `└──` for the last, `│` for still-continuing ancestors,
  spaces for finished ones. Standard Unicode box-drawing
  (U+251C/2514/2502/2500).
- `--level N`: cap recursion depth at N levels. Value
  parses as a positive integer in the next argv slot
  (`darshini -T --level 2 docs` shape — matches `tree
  --level` / `eza --level`). Without `--level`, recurses
  to the bottom.
- `-T` composes with `-l`: long-format columns
  (perms / size / mtime) prefix the tree connector +
  name. Composes with `-h` for human-readable sizes,
  `--no-color` / `--no-icons` for plain output.
- Symlink-to-dir handling: tree does NOT recurse into
  symlinked directories (matches `tree(1)` / `eza` default;
  an opt-in follow flag is out of scope for v1.0 per the
  M10 frozen flag set).
- `src/tree.cyr` — `render_tree(root, max_depth, want_long,
  want_human, want_color, want_icons)` top-level entry +
  the depth-stack recursion (`_tree_recurse`).
  Testable helpers `_tree_prefix_buf` /
  `_tree_connector_buf` write the byte sequences into a
  caller buffer for direct assertion.
- `src/main.cyr` — argv parser learns `-T` (short) /
  `--tree` (long) / `--level N` (long with required int
  value). `_parse_pos_int` validates non-empty digit-only
  cstr; rejects empty / signed / non-digit input.
- Tests: 28 new assertions across `_tree_connector_buf`
  (exact bytes for both is_last variants), `_tree_prefix_buf`
  (empty / single-slot / mixed depth-stack patterns),
  `_parse_pos_int` (positive ints, zero, empty, negative,
  mid-string non-digit). Total now 174/174.

### Notes
- Size column in `-T -l` is not max-aware (each row emits
  the natural-width size). The tree's vertical structure
  provides enough visual rhythm; a two-pass walk to compute
  max-size-per-subtree was deemed over-engineering for v1.0.
- Box-drawing characters render correctly in any modern
  UTF-8 terminal — no Nerd Font assumption (icons remain
  separate, gated by `--no-icons`). No ASCII fallback flag
  at v1.0 (`tree(1)`'s `--charset=ascii` equivalent); revisit
  post-v1 if a serial-console / dumb-terminal user asks.
- `-1` under `-T` is a no-op: tree mode is inherently
  one-entry-per-line. Doesn't error — the bundling stays
  forgiving.

## [0.6.0] — M5: icons via CYML mapping

### Added
- Per-entry icons on TTY output. Lookup precedence per
  ADR 0002: exact filename → filename prefix → file-type
  override → extension match → generic file glyph. Every
  entry gets a glyph (no "blank" cells).
- `--no-icons`: long-form flag to force-off even on a TTY.
  Bundles fine with the rest of the v0.6.0 flag set.
- Pipe-aware default: stdout-not-a-TTY → no icons (no bytes
  emitted, no column-budget impact). Same gate as M3 columns
  and M4 color.
- `icons/default.cyml` — human-readable source of truth for
  the icon mapping. Nerd Font v3+ glyphs across Devicons,
  Material, Font Awesome, Octicons. 80+ extensions, 7 exact
  filenames, 5 filename prefixes.
- `src/icons.cyr` — compile-baked lookup chain mirroring
  `icons/default.cyml`. `icon_for_entry(name, mode)` returns
  the glyph cstr (or 0 on stat-failed entries).
  `icon_display_width()` returns the fixed 2-cell budget per
  ADR 0002.
- `docs/adr/0002-icon-format.md` — second ADR. Locks the
  schema, the lookup precedence, the display-width
  assumption, and the compile-baked-vs-runtime-CYML decision.
- `src/color.cyr` — `compute_decor(entries, dir_str,
  want_color, want_icons)` replaces `compute_colors`. Single
  lstat pass over the entry list now produces both the colors
  vec and the icons vec (down from 2N lstats to N when both
  decorations are on).
- `emit_decorated(name, color, icon, icon_pad)` — extended
  emit primitive; covers the bare-name, name-with-color,
  name-with-icon, and name-with-both shapes. Old
  `emit_colored` kept as a thin wrapper.
- Column-fit math: `pick_cols(entries, tw, icon_width)` and
  `_columns_total_width(..., icon_width)` take a fixed
  per-cell offset when icons are enabled. Padding diff
  unchanged (icon_width is uniform across the column).
- Tests: 25 new assertions across `icon_display_width`,
  `icon_for_entry` (each lookup precedence rule), and
  `pick_cols + icon_width` interactions. Total now 132/132.

### Notes
- Icon glyphs require a Nerd Font v3+ patched font on the
  user's terminal. Terminals without one render replacement
  characters; the documented fallback is `--no-icons`. No
  auto-detection — terminal-query for font availability isn't
  reliable across emulators.
- `icons/default.cyml` is the spec but is NOT parsed at
  runtime. The mapping is compile-baked into `src/icons.cyr`
  for startup speed (rationale in ADR 0002). When adding an
  icon, edit BOTH files. Runtime CYML loading is a v1.1
  candidate.
- Per-icon color overrides (LS_COLORS-style) deferred to v1.1.
  Each icon takes the name's mode color per ADR 0001.
- File-type icons (folder, link, fifo, ...) are hard-coded in
  `src/icons.cyr` rather than in the CYML — could lift to a
  `[type_overrides]` table when runtime-CYML lands.

## [0.5.0] — M4: color via darshana

### Added
- Per-entry color on TTY output. File-type detection drives the
  ADR-0001 palette: directory → blue, symlink (live) → cyan,
  symlink (broken) → red, executable regular file → green,
  fifo → yellow, socket → bright magenta, block / char device
  → bright yellow, regular non-executable → no color.
- `--no-color`: long-form flag to force-off even on a TTY.
  Bundles parse-fine with other short flags (`-l --no-color`).
- Pipe-aware default: stdout-not-a-TTY → no color (no escape
  bytes emitted). Same gate as M3's single-column-on-pipe.
- Broken-symlink detection: symlinks pay an extra `sys_stat`
  per entry to distinguish broken (red) from live (cyan). Cost
  scales with symlink count, not entry count.
- `src/color.cyr` — `color_for_mode(mode)` pure picker,
  `compute_colors(entries, dir_str)` parallel-vec builder with
  broken-symlink follow, `emit_colored(name, color)` write wrap.
- `docs/adr/0001-color-scheme.md` — first ADR. Frozen palette
  for v1.0, divergence-vs-`ls` notes, accessibility rationale.
- `[deps.darshana]` — first external dep, pinned at 0.5.3. All
  ANSI escapes route through `tty_sgr` / `tty_sgr_reset` per
  the CLAUDE.md "no raw ANSI inline" hard rule.
- Tests: 14 new assertions on `color_for_mode` (every file
  type → its SGR code). Total now 107/107.

### Notes
- The 8/16-color named-color subset is the v1.0 contract. 256
  / 24-bit truecolor primitives are available in darshana but
  unused — keeps the palette portable across serial consoles,
  tmux scrollback, screen readers, log archives.
- `NO_COLOR` / `CLICOLOR` env-var honors aren't wired. `--no-color`
  covers the explicit override; TTY detection covers script
  safety. Env-var support is a follow-up if downstream asks.
- LS_COLORS-style dotfile config is out-of-scope per roadmap.

## [0.4.0] — M3: multi-column auto-layout + `-1`

### Added
- Multi-column auto-layout: bare `darshini` on a TTY now packs
  entries into as many columns as fit, vertically-then-
  horizontally (`ls`-default shape). 2-space separator,
  per-column max width, partial trailing rows don't emit
  trailing whitespace.
- `-1` / `--single`: force single-column output even on a TTY.
  Matches `ls -1` semantics. Bundles with `-l` / `-h` (e.g.
  `-1l` is well-formed; `-l` wins).
- Pipe-aware default: stdout-not-a-TTY → single column. Probed
  via `ioctl(TIOCGWINSZ)`; failed ioctl → 0 → single column.
  TTY-reports-0-cols → 80-col fallback per roadmap.
- `src/columns.cyr` — `term_width()`, `pick_cols(entries, tw)`,
  `render_columns(entries, tw)`. The picker rejects phantom
  layouts where the trailing column would be entirely empty
  (e.g. 5 entries × "4 cols × 2 rows" really only fills 3 cols).
- Tests: 19 new assertions across `pick_cols` (uniform 5/100/1000-
  entry vecs, jagged widths, degenerate inputs, narrow TTYs)
  and `_columns_total_width` (exact byte width for known
  layouts). Total now 93/93.

### Notes
- Vertical-then-horizontal is the contract per roadmap; column-
  major fill (`ls -x`) is out of scope for v1.0.
- `COLUMNS` env-var override (which `ls` honors) isn't wired —
  defer; ioctl is the single source of truth right now.
- M3 doesn't change `-l` behavior — long-format rows are always
  one per line, columns kick in only on the default short-form
  path.

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

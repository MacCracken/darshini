# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.1.2] — v1.1.2: hot-path optimizations

Three perf wins from the v1.2 candidates list in
[`docs/benchmarks.md`](docs/benchmarks.md). No behavior
change; non-breaking under the M10 freeze. 233/233 tests
holding.

### Performance

- **Hybrid sort** — insertion-sort cutoff at merge-sort
  leaves (< 16 elements). Standard optimization shipped by
  Java's `Arrays.sort` and libstdc++ `std::sort`. Restores
  best-case perf at small N (already-sorted 1k:
  635 µs → 493 µs, 1.3× faster). Slight regression on the
  fully-reverse-sorted worst case (640 µs → 820 µs) —
  accepted: real-world directories are nearly-sorted, not
  adversarial; absolute still well under any perception
  threshold and still **44× faster than v1.0**.
- **`pick_cols` widest-aware short-circuit** — pre-scans
  the widest entry; if it doesn't fit in `term_width`,
  returns 1 col immediately, skipping the entire per-col
  iteration loop. Bench `pick_cols 1k@10
  widest-doesnt-fit`: 33 µs (was a full iteration).
  Cap stays loose (1-char per col) — see source NOTE for
  why a widest-uniform cap would reject valid jagged
  layouts.
- **`_path_join_into` buffer reuse** — new local helper
  in `src/color.cyr` writes `dir + "/" + name + "\0"` into
  a caller-allocated cstr buffer. `compute_decor` allocates
  one 4096-byte buf per listing and reuses across entries
  instead of N str_builder allocations. **4.2× faster**
  per call (305 ns → 72 ns). lib/fs.cyr's `path_join` stays
  for tree.cyr's recursion (each frame needs its own
  persistent allocation).

### Notes

- v1.1.2 closes out the entirety of the v1.2+ hot-path
  optimization candidates from `docs/benchmarks.md`. v1.2
  backlog is now just mtime localization + post-v1 platforms.
- New bench coverage: `pick_cols 1k@10 widest-doesnt-fit`,
  `path_join (str_builder)`, `_path_join_into (buf reuse)`.
- No new tests; the changes are pure perf (no observable
  behavior). Existing tests confirm no regression (caught
  one tighter-cap bug in pick_cols mid-implementation —
  loosened back to 1-char min-per-col, kept the
  widest-doesn't-fit short-circuit).

## [1.1.1] — v1.1.1: multi-path argv

### Added

- **Multi-path argv** — `darshini path1 path2 path3 ...`. Per
  path classification + ls(1)-style ordering:
  1. Errors are emitted to stderr (process continues + exits 1).
  2. Non-directory paths render together in argv order, no
     header.
  3. Directory paths each get a `<path>:` header (when more
     than one path is in play) and a blank line between
     sections.
- `-d` short-circuits the file/dir split: each path renders as
  a single entry, no headers, no blanks. With `-F` adds the
  trailing `/`. Retires the maintainer's `ldir` / `lldir`
  shell-glob aliases — `darshini -d */` and
  `darshini -ld */` now both work.
- `-T` per-path tree with a blank line between trees (the
  tree's root line already names the path, so no extra header).
- Single-path invocations are byte-identical to v1.1.0 — no
  header, no behavior shift.

### Changed

- `parse_cli` now populates a caller-allocated `vec<cstr>` of
  positional args instead of writing a single `out_path`. Empty
  vec → `run_all` defaults to `"."`.
- Exit code propagation: partial-failure (one path errors, others
  succeed) returns 1. Matches `ls` behavior.

### Dotfile retirement complete

The maintainer's `~/.config/zsh/.aliases.zsh` migration: all
six original eza aliases now run through darshini.

- `ll = darshini -l --git`
- `l = darshini`
- `lfiles = darshini -F`
- `llfiles = darshini -lF --git`
- `ldir = darshini -d */` (was `eza -d */`)
- `lldir = darshini -ld */` (was `eza -ld */`)

### Notes

- Multi-path support was originally slated for v1.2 alongside
  mtime localization + platform work; pulled forward this
  release to close the dotfile-migration story.
- Tests stayed at 233/233 (unit tests don't touch the
  per-path orchestrator; multi-path covered by new CI smoke).
- v1.2 backlog now: mtime localization + post-v1 platforms
  (aarch64 Linux → macOS / BSD / Windows). Other items
  remain on the v1.2+ perf-candidates list per
  [docs/benchmarks.md](docs/benchmarks.md).

## [1.1.0] — v1.1: backlog burndown

Pure additions + internal upgrades, all non-breaking under the
M10 freeze contract.

### Added

- `--help` — flag summary + exits 0. Back-fills the M10
  roadmap omission.
- `--version` — prints `darshini 1.1.0` + exits 0. Same back-fill.
- `-F` — classify entries with POSIX-style trailing indicator:
  `/` directory, `*` executable regular file, `@` symlink,
  `|` fifo, `=` socket. Block / char devices have no POSIX
  indicator and don't emit one. Composes with every existing
  format (long / multi-column / single-column / tree).
  Display-width: 1 cell per entry (with-or-without indicator;
  padding reserves the cell for alignment).
- `-d` — list the path as a single entry instead of listing its
  contents (matches `ls -d` shape). Composes with `-l` (single
  long-format row) and `-F` (trailing `/` for directories).
  Multi-path support (`-d dir1 dir2 ...`) stays out of scope —
  v1.2 candidate.

### Performance

- `sort_entries` upgraded from insertion sort → top-down
  merge-sort. Stable, O(N log N) worst case (was O(N²)).
  Bench delta:
  - 1k reverse-sorted entries: **36.3 ms → 640 µs (56× faster)**
  - 100 reverse-sorted entries: 391 µs → 48 µs (8× faster)
  - 1k already-sorted: 114 µs → 635 µs (5.6× slower —
    overhead of the auxiliary vec; absolute still sub-ms, well
    under any perception threshold)
  Caller contract unchanged; allocates O(N) scratch internally.
- `_git_find_tracked` upgraded from O(N) linear scan → O(1)
  average hashmap lookup. Built once at `git_open` time, lives
  on the `GitCtx`. Quadratic → linear total cost for repos with
  thousands of tracked files. Invisible on this repo's 117-file
  index (sub-µs either way); matters at scale.

### Internal

- `cyrius.cyml` [deps].stdlib gains `hashmap`.
- `GitCtx` struct grew 40 → 48 bytes (new `tracked_map` slot
  at +40).
- `emit_decorated` and the four render-path entry points
  (`print_entries`, `render_columns`, `render_long`,
  `render_long_one`, `render_tree`) gained `classify_char` +
  `classify_pad` params. `compute_decor` gained a parallel
  `classifies` vec at +32.

### Dotfile retirement progress

The maintainer's `~/.config/zsh/.aliases.zsh` migration
continues. v1.0 retired `ll` and `l`; v1.1 retires `lfiles`
and `llfiles` via the new `-F` flag. `ldir` / `lldir` need
multi-path argv support (v1.2 candidate); they stay on eza
until then.

### Notes

- v1.1 is a SemVer-minor bump per the new flags. The M10
  freeze contract holds — no behavior changed for any v1.0
  flag, only additions.
- Tests stayed at 233/233. New flags don't add their own
  test functions (they thread through existing emit code
  whose contracts didn't change); their effects are
  exercised end-to-end via the binary in CI smokes.
- v1.2 backlog (per user direction): mtime localization,
  multi-path argv, post-v1 platforms (aarch64 Linux first,
  then macOS / BSD / Windows).

## [1.0.0] — M10: v1.0 freeze

### Breaking

The **CLI flag surface is now frozen**. Future releases under
the 1.x line will not change the meaning, removal, or
default-on-or-off behavior of any of:

- `-l` / `-h` / `-1` / `-T` / `--tree` / `--level N`
- `--git` / `--mime` / `--no-color` / `--no-icons`

Frozen behaviors per ADR:
- Color palette + per-file-type assignment —
  [ADR 0001](docs/adr/0001-color-scheme.md)
- Icon glyph schema + lookup precedence —
  [ADR 0002](docs/adr/0002-icon-format.md)
- Mime detection precedence + magic-byte set —
  [ADR 0003](docs/adr/0003-mime-detection.md)
- Tree-mode connector charset + composition rules —
  [ADR 0004](docs/adr/0004-tree-mode.md)

Frozen defaults:
- Pipe-aware: stdout-not-a-TTY suppresses columns / color /
  icons / mime automatically.
- Case-insensitive alphabetical sort, locale-free.
- mtime in UTC under `-l` (post-v1 will add localization
  without breaking the UTC default).
- Symlink-to-dir not followed under `-T`.

Adding new flags is non-breaking. Changing the meaning of any
existing flag is a breaking change requiring a 2.x bump.

### Added

- v1.0.0 release notes (this entry) — declares the freeze.

### Notes

- No source changes vs v0.9.1. The freeze IS the contract
  change per Keep-a-Changelog rationale.
- Platforms — Linux x86_64 only through 1.x. Other platforms
  remain post-v1 (separate version line, not blocked on this
  freeze).
- Three minor findings from the [2026-05-23 audit](docs/audit/2026-05-23-audit.md)
  remain on the v1.1+ enhancement backlog
  (`sort_entries` merge-sort upgrade, git tracked-set hashmap,
  per-listing alloc-arena reset). None block v1.0.
- v1.1 candidates surfaced from the maintainer's dotfile
  migration: `-F` (classify) and `-d` (list-dir-as-self) to
  retire the remaining `eza` aliases (`lfiles`, `llfiles`,
  `ldir`, `lldir`).
- v1.1 candidate from M2 notes: mtime localization without
  losing the UTC default.

## [0.9.1] — M9: pre-v1 audit sweep

### Added
- [`docs/audit/2026-05-23-audit.md`](docs/audit/2026-05-23-audit.md)
  — full P(-1) hardening pass: cleanliness sweep, internal
  code review (var-buf sizing, syscall error paths, path
  traversal, external-format parser robustness, allocation
  patterns, integer overflow), external research (eza
  feature catalog with deliberate-omission decisions),
  documentation audit. 0 critical / 0 major / 3 minor
  findings — all accepted as v1.1+ enhancements.
- [`docs/benchmarks.md`](docs/benchmarks.md) — bench
  baseline captured at v0.9.0. Typical-listing total
  ~120 µs algorithmic + ~300-500 µs stat I/O. Worst-case
  1k-reverse `sort_entries` 36 ms (flagged as v1.1
  optimization candidate).
- `tests/darshini.bcyr` — real benchmark suite replacing
  the M0 noop stub. 10 benches across `sort_entries`
  (best/worst), `pick_cols`, `color_for_mode`,
  `icon_for_entry`, `mime_for_entry`. Reproducible via
  `cyrius bench tests/darshini.bcyr`.
- [`docs/adr/0004-tree-mode.md`](docs/adr/0004-tree-mode.md)
  — back-filled per CLAUDE.md P(-1) "tree-mode ADR"
  requirement. Documents the connector charset, recursion
  contract, composition rules with `-l` / `--git` /
  `--mime`, and the alternatives-considered list.

### Notes
- No source changes — audit was read-only review + docs.
- v0.9.1 is the pre-freeze checkpoint. v1.0.0 is the
  contract-freeze tag with no behavior changes.

## [0.9.0] — M8: `--mime` type column

### Added
- `--mime`: per-entry mime type, shown as a left-aligned
  column under `-l` (only under `-l` — see ADR 0003 for
  why short / multi-column / tree formats don't get it).
- Detection precedence (per ADR 0003, intentionally
  diverging from the roadmap's literal "magic-first" text
  for cost reasons):
  1. Non-regular file type → `inode/*` (directory / symlink /
     fifo / socket / blockdev / chardevice).
  2. Exact `[filenames]` match (Makefile, Dockerfile, LICENSE,
     VERSION, README, CHANGELOG, .gitignore, .gitattributes).
  3. Lowercased `[extensions]` match (80+ entries, mirrors
     icons/default.cyml shape).
  4. Executable bit set on a regular file →
     `application/x-executable`.
  5. Magic-bytes probe (open + read 16 bytes): ELF / PNG /
     JPEG / GIF / ZIP / gzip / bzip2 / xz / 7z / PDF / shebang.
  6. Fallback → `application/octet-stream`.
- `docs/adr/0003-mime-detection.md` — third ADR. Documents
  the precedence divergence + magic-byte set + why
  `--mime` is `-l`-only at v1.0.
- `mime/default.cyml` — human-readable mime mapping (source
  of truth for the compile-baked table in `src/mime.cyr`,
  same pattern as ADR 0002 for icons).
- `src/mime.cyr` — `mime_for_entry` master + the four
  per-precedence-tier helpers.
- `src/color.cyr` `compute_decor` extended again: now also
  produces a parallel `mimes` vec when requested. Single
  lstat pass still covers all four decoration vecs (colors,
  icons, git, mimes).
- `src/long.cyr` `render_long` two-pass for mime: first
  scan finds max mime width, second emits each row with
  the mime column left-aligned + padded.
- Tests: 36 new assertions across `_mime_for_inode`,
  `_mime_for_filename` (exact-only, not prefix),
  `_mime_for_ext`, `_mime_for_magic_bytes` (synthetic
  byte buffers per signature), `mime_for_entry` full
  precedence chain. Total now 233/233.

### Notes
- `--mime` without `-l` is parsed but silent (no column).
  Column placement under short / multi-column / tree
  would clash with the fixed-width prefix budget those
  layouts rely on. Future fixed-width-truncated variant
  is a post-v1 enhancement if asked.
- Cost ceiling: 0 extra opens for entries with a known
  extension (~95% of typical listings). 1 open + read(16)
  + close per extensionless non-executable regular file.
- `application/zip` mime covers JAR / DOCX / ODT containers
  too. Acceptable v1.0 imprecision; deeper inspection
  needs unzipping (out of scope).
- README / CHANGELOG / LICENSE filenames are EXACT-match
  only here (in contrast to icons.cyr's filename
  prefixes) — so `README.md` correctly reports
  `text/markdown`, not `text/plain`.

## [0.8.0] — M7: `--git` status column

### Added
- `--git`: per-entry git status, read directly from
  `.git/index` (v2 binary) + `.gitignore` +
  `.git/info/exclude`. NO `git` subprocess per the
  CLAUDE.md hard rule — every byte parsed from
  on-disk files via sys_open + sys_read.
- Status chars (single char, 2-cell column with trailing
  space): `.` tracked (clean), `M` tracked (modified —
  mtime_sec or size differs from index), `?` untracked,
  `!` ignored.
- Directory entries aggregate: a directory is shown as
  tracked (`.`) when ANY indexed path lives under it
  (git's index has no directory entries, only files).
- Silent skip outside a git repo: when `.git/` isn't
  in the ancestor chain, `--git` is a no-op (no column,
  no error). Acceptance criterion per roadmap M7.
- Composes with `-l` (column slots after mtime, before
  the icon/name decoration), short / multi-column modes
  (decoration prefix), and tree mode (per-entry).
- `src/git.cyr` — big-endian decode helpers, `.git/index`
  v2 parser, minimal `.gitignore` parser (exact basename,
  `*suffix` glob, `dir/` directory-only), `git_open`
  top-level (find root → load context), `git_status_for`
  classifier with directory-aggregate semantics.
- `src/color.cyr` `compute_decor` extended: single lstat
  pass now also produces the git_status vec when a
  GitCtx is supplied. `emit_decorated` gains
  `(git_char, git_pad)` params; old `emit_colored` shim
  forwards 0s.
- Cell-width math: `pick_cols` / `_columns_total_width`
  treat `--git`'s 2-cell prefix the same way they treat
  icons — uniform per-cell offset, padding diff
  unaffected.
- Tests: 23 new assertions across `_be_u32` / `_be_u16`
  (multi-byte big-endian decode), `_git_parse_index`
  (header validation, version check, empty index),
  `_git_match_one` (exact / suffix-glob / dir-only),
  `_git_listing_rel` (prefix-strip edge cases). Total
  now 197/197.

### Notes
- MVP scope: `.git/index` v2 only (v3+ rejected; index-v4
  path-compression unsupported). Linear-scan lookup of
  tracked paths (acceptable through low-thousands files;
  hashmap upgrade is post-v1). `.gitignore` subset:
  exact-basename + `*<suffix>` + `dir/`. Skips negation
  (`!`), brace expansion, mid-string globs, `**`
  deep-match. Full gitignore semantics would 5x the
  module size; v1.0 ships the 80% case.
- "Added/staged-vs-HEAD" distinction not shown — would
  require HEAD object parsing. Treated as tracked.
  Defer to post-v1.
- nsec-precision modification check skipped (filesystems
  often return 0 nsec, would false-flag clean files).
  Only `mtime_sec` and `size` are compared.
- The `.git/` directory itself shows as `?` (not in
  index, not in .gitignore). Acceptable; eza skips it
  with a built-in but darshini stays uniform.
- ADR not authored for M7 — git format is the
  upstream-frozen contract, no original design decisions
  worth documenting (in contrast to ADRs 0001/0002).
  The scope-cuts above are the audit trail.

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

# darshini — Roadmap

> Milestone plan. M0–M10 (v1.0) complete; 1.x cycle tracks
> non-breaking additions + perf. State lives in
> [`state.md`](state.md); this file is the sequencing.

## v1.0 criteria — ✅ all met (shipped 2026-05-23)

The darshini v1.0 contract: eza core-feature parity for the
common-case `ls` workflow, with stable CLI flag surface and frozen
icon-set format. Tree mode, git-status column, and mime-type
recognition all green on the maintainer's daily-use targets.

- [x] CLI flag surface frozen — `-l` / `-h` / `-1` / `-T` /
      `--level N` / `--no-color` / `--no-icons` / `--git` /
      `--mime`. `--help` / `--version` shipped at v1.1.0 as
      a non-breaking addition; `-a` collapsed into the
      "show hidden by default" semantics (no flag needed).
- [x] CYML icon-mapping schema documented and frozen
      ([ADR 0002](../adr/0002-icon-format.md)).
- [x] `icons/` ships a curated default mapping covering common
      extensions + special files (`Makefile`, `README*`,
      `.gitignore`, …). See `icons/default.cyml`.
- [x] Test coverage: 233 assertions across every pure helper
      + CI smokes for flag combinations + error paths.
- [x] Benchmarks captured in
      [`docs/benchmarks.md`](../benchmarks.md) for walk+render
      on representative trees.
- [x] CHANGELOG complete from v0.1.0 onward.
- [x] Security audit pass —
      [`docs/audit/2026-05-23-audit.md`](../audit/2026-05-23-audit.md).

## Milestones

### M0 — Scaffold (v0.1.0) — ✅ shipped 2026-05-19

- `cyrius init` scaffold landed
- `./build/darshini` prints scaffold version and exits
- Doc-tree per [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md)

### M1 — Directory walk + basic listing (v0.2.0)

The minimum viable output: walk the cwd, list entries one per line,
exit. No colors, no icons, no columns — establish the walk + stat
pipeline.

- `darshini` lists the cwd's entries, one per line
- `darshini <path>` lists `<path>`'s entries (file or directory)
- Sorted alphabetically (case-insensitive default; revisit at M4)
- Tests: happy path + empty dir + permission denied + nonexistent path
- **Dep gate**: stdlib only
- **Acceptance**: `darshini` in this repo prints `CHANGELOG.md / CLAUDE.md / cyrius.cyml / …`

### M2 — Long format (`-l`) (v0.3.0)

- `-l` flag — long-form rows: permissions / size / mtime / name
- `-h` flag — human-readable sizes (4.2K instead of 4321)
- mtime format: `YYYY-MM-DD HH:MM` (locale-free, stable)
- Tests: every column for known fixtures
- **Dep gate**: M1
- **Acceptance**: `darshini -lh` produces aligned columns.

### M3 — Multi-column auto-layout (v0.4.0)

When stdout is a TTY and `-l` isn't passed, fit entries into
multiple columns based on terminal width.

- Terminal-width detection via `ioctl(TIOCGWINSZ)` (or fallback to 80)
- Column-fit algorithm: max widths, vertical-then-horizontal layout
- `-1` flag — force single-column (matches `ls -1` semantics)
- Tests: 1k-entry directory, 100-entry directory, 5-entry directory
- **Dep gate**: M1
- **Acceptance**: `darshini` in a 100-entry dir produces a clean
  multi-column layout in an 80-col terminal.

### M4 — Color via darshana (v0.5.0)

- `[deps.darshana]` wired
- Per-entry color by file type (dir, executable, symlink, broken
  symlink, regular file)
- TTY auto-detect (no color on pipe)
- `--no-color` flag to force-off
- ADR: `docs/adr/0001-color-scheme.md` — palette + rationale
- **Dep gate**: darshana ≥ 0.3.0
- **Acceptance**: `darshini` colorizes on TTY; `darshini | cat`
  emits plain output.

### M5 — Icons (v0.6.0)

- CYML icon mapping: `icons/default.cyml` maps `<ext>` → `<glyph>`
  + ANSI color, with special-case entries for well-known filenames
  (`Makefile`, `Dockerfile`, `README*`, etc.)
- ADR: `docs/adr/0002-icon-format.md` — schema + rationale
- `--no-icons` flag to suppress
- Tests: every shipped icon renders for its trigger
- **Dep gate**: M4 (icons inherit from darshana)
- **Acceptance**: `darshini -l` in this repo shows the Cyrius icon
  for `.cyr`, the markdown icon for `.md`, etc.

### M6 — Tree mode (`-T`) (v0.7.0)

- `-T` / `--tree` flag — recursive display with box-drawing characters
- `--level N` to cap depth
- Reuses M2 row format per entry; box-drawing prefixes per entry
- Tests: nested dirs, symlink-to-dir (don't recurse into it by
  default; explicit flag to follow)
- **Dep gate**: M2 + M5
- **Acceptance**: `darshini -T --level 2` on this repo shows the
  expected two-level box-drawn tree.

### M7 — Git-status column (`--git`) (v0.8.0)

- `--git` flag — extra column showing per-entry git status (modified,
  added, ignored, untracked, clean)
- Reads `.git/index` + `.git/info/exclude` + `.gitignore` directly;
  no `git` subprocess
- Skips silently when no `.git/` in ancestor chain (no wasted stat)
- Tests against a controlled test repo with each status type present
- **Dep gate**: M2
- **Acceptance**: in this repo, `darshini -l --git` shows
  appropriate status flags for tracked / modified / untracked files.

### M8 — Mime-type recognition (`--mime`) (v0.9.0)

- `--mime` flag — extra column showing detected mime type
- Detection via magic-bytes table (CYML-defined; ships in `mime/`)
- Falls back to extension lookup when magic-bytes inconclusive
- ADR: `docs/adr/0003-mime-detection.md`
- **Dep gate**: M5
- **Acceptance**: `darshini -l --mime` shows `text/markdown`,
  `application/x-cyrius`, `application/x-executable` etc.

### M9 — Harden + dogfood — ✅ shipped 2026-05-23 (v0.9.1)

- P(-1) hardening pass complete; audit doc at
  [`docs/audit/2026-05-23-audit.md`](../audit/2026-05-23-audit.md).
- Bench baseline captured in
  [`docs/benchmarks.md`](../benchmarks.md).
- ADR 0004 (tree mode) back-filled.
- Maintainer's daily `ls` alias migrated to darshini at v1.1.x.

### M10 — v1.0.0 — ✅ shipped 2026-05-23

- CLI flags + icon format + color scheme + mime detection
  + tree mode all frozen.
- CHANGELOG `[1.0.0]` `Breaking` section documents the
  freeze (no signature changes — the freeze is the contract
  change per the M10 design).
- v1.0.0 cut.

## 1.x line — non-breaking additions + perf

- **v1.1.0** (2026-05-23) — `--help` / `--version` / `-F` /
  `-d` flags, merge-sort `sort_entries`, hashmap
  `_git_find_tracked`.
- **v1.1.1** (2026-05-23) — multi-path argv
  (`darshini dir1 dir2 ...`). Completes the maintainer's
  eza-alias retirement.
- **v1.1.2** (2026-05-23) — hot-path optimizations: hybrid
  sort (insertion-cutoff at merge-sort leaves),
  `pick_cols` widest-aware short-circuit, `_path_join_into`
  buffer reuse in `compute_decor`.

1.x backlog:
- **mtime localization** — opt-in flag; keep UTC default.
- **Platform support** — aarch64 Linux → macOS / BSD /
  Windows. Arch-specific sites enumerated in
  [`state.md`](state.md) "Known gotchas".

## Out of scope (for v1.0)

The list keeps future contributors from adding to v1.0 by accident.

- **Gitignore-aware filtering** — out of scope; the `--git` column
  shows status, doesn't filter. Filter with `find` or shell globs.
- **Extended attributes / ACLs** — out of scope.
- **`--sort=size` / `--sort=mtime` / `--sort=…`** — out of scope for
  v1.0; alphabetical only. (Reconsider for v1.1 if there's demand.)
- **Recursive `-R` (non-tree)** — out of scope; use `-T --level N`.
- **AI-augmented features** (`chakshu`-style mime prediction,
  repo-context-aware coloring) — explicitly v2.0 territory.
- **Windows / macOS** — Linux + AGNOS-native only for v1.0.
- **Configurable output via dotfiles** — out of scope. The CLI flag
  surface is the contract; environment-driven theming is the
  neofetch trap and we're not falling into it.

## Cross-references

- [`state.md`](state.md) — live status (supported features, icon coverage)
- [`../../CHANGELOG.md`](../../CHANGELOG.md) — release history
- [darshana](https://github.com/MacCracken/darshana) — rendering substrate dep

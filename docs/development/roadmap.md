# darshini — Roadmap

> Forward-looking only. What shipped is in the
> [CHANGELOG](../../CHANGELOG.md); what is true right now is in
> [`state.md`](state.md). This file is the sequencing from here.

## Where we are

**v1.6.0** (2026-10-15). The v1.0 contract (M0–M10, shipped
2026-05-19 → 05-23) is intact: eza-style listing with long format,
multi-column layout, color, icons, tree mode, a git-status column and a
mime column, pipe-aware. The 1.x line since has added `--help` /
`--version` / `-F` / `-d` / multi-path / `--`, AGNOS as a target,
darshana's terminal primitives, a `--git` column that answers what git
answers (1.5.0), cell-accurate columns and `--local-time` (1.6.0), two
security sweeps
([2026-08-23](../audit/2026-08-23-audit.md),
[2026-10-15](../audit/2026-10-15-audit.md)) and the hot-path work in
[`benchmarks.md`](../benchmarks.md).

## The 1.x rules

- **Frozen**: the flag surface, the pipe output bytes of a correct
  listing, the success / error exit classes, the icon-mapping format
  (ADR 0002), the color scheme (ADR 0001), mime precedence (ADR 0003),
  tree shape (ADR 0004).
- **Breaking** (→ 2.0): a change to the exit code or default output
  bytes of a *correct* run (CLAUDE.md). Fixing output that was wrong —
  a lying `--git` column, a trailing pad, a raw control byte — is
  `Fixed`, as v1.3.2 and v1.4.1 did. A new opt-in flag is `Added`.
- **Bump size**: patch for fixes, internals, toolchain; minor for new
  flags, new targets, a large behavior delta in an existing column, or
  absorbing a breaking upstream (convention).

## Path

### 1.4.x — patch line: internals and gates, no new surface

- **1.4.1** — ✅ audit and repair sweep
  ([audit](../audit/2026-10-15-audit.md)).
- **1.4.2** — ✅ internals + CI, zero output change: the stdlib sort
  (`vec_sort_by`), the cross targets run in CI (aarch64 suite + fuzz +
  output parity under qemu; agnos suite + fuzz under mirshi), the
  icon / mime table-drift gate, and golden examples.

### 1.5.0 — ✅ `--git` accuracy ([ADR 0005](../adr/0005-git-status-semantics.md))

git's ignore rules in full (a `wildmatch` port), every ignore source in
git's precedence, excluded-directory inheritance, `gitdir:` submodules
and worktrees (submodule status by `HEAD`), no mark for `.git`,
`safe.directory` ownership — verified against `git check-ignore` (63k
random paths locally; `tests/git-parity.sh` in CI). Left out by
decision (ADR 0005): staged-vs-unstaged, per-directory dirty
aggregation, `include` / `includeIf`, `GIT_DIR` / `GIT_WORK_TREE`,
`core.ignoreCase`.

### 1.6.0 — ✅ display correctness

Column widths in terminal cells (a generated Unicode 16 width table);
path arguments rendered as one decorated listing (color, icons, `--git`,
`-F`, the grid, one aligned `-l` table); `--mime` under `-T -l`;
`--local-time` (TZif + POSIX TZ strings, verified against `date(1)`);
pre-1970 mtimes rendered as dates.

### 1.7.0 — platforms

- **aarch64 Linux, declared.** Output has matched x86_64 byte-for-byte
  since v1.4.0 (304 / 304 captures at v1.4.1), and since 1.4.2 CI runs
  its suite, fuzz harness and an output-parity matrix under qemu on
  every push. What remains is the owner's call — and a release asset.
- **AGNOS `lstat`** (#102, agnos 1.56.53): symlinks currently render as
  their target there. Changes agnos output; needs a mirshi run proving
  #102 is emulated.
- **AGNOS decoration** — blocked upstream: needs a per-fd terminal test
  in agnos (its `winsize#60` describes the console, not fd 1, so using
  it would decorate `darshini > file`). Then darshana's Linux arm of
  `term_width` becomes the whole function.
- **macOS / BSD** — needs a darshana arm for `tty_winsize` /
  `tty_isatty`; the stdlib has the stat layouts and `getdirentries`.

### Needs an owner decision (unscheduled)

- **Symlink targets under `-l`** (`link -> target`). Changes `-l`
  output bytes: an opt-in flag in 1.x, or the default in 2.0.
- **Icon precedence for directories.** A directory named `README.d` or
  `Makefile` gets the README / Makefile glyph, not the folder (ADR 0002,
  corrected at v1.4.1). eza does the opposite. A TTY-only icon change.
- **Exit status when entries can't be stat'd.** In a readable but
  unsearchable directory darshini prints `?` rows and exits 0; `ls`
  exits 1. (An *unreadable* directory exits 1 since v1.4.1.)
- **`NO_COLOR` / `CLICOLOR`.** A widely followed convention, but an
  environment knob, against the "no environment-driven theming" line
  below.
- **Icons as data.** CLAUDE.md says new icons are data edits; the
  tables are compile-baked (ADR 0002). Runtime CYML loading would make
  the principle true at a startup-parse cost — or the principle changes.
- **Pre-release tags** (`2.0.0-rc1`) do not trigger `release.yml`.

## Out of scope for 1.x

Kept so nobody adds these by accident.

- **Gitignore-aware filtering** — the `--git` column shows status, it
  doesn't filter. Filter with `find` or shell globs.
- **Extended attributes / ACLs.**
- **`--sort=size` / `--sort=mtime` / …** — alphabetical only. Reopen
  only on real demand.
- **Recursive `-R` (non-tree)** — use `-T --level N`.
- **Following symlinks into directories under `-T`** — would need a
  visited-inode set (ADR 0004).
- **A mime magic cache** between runs (benchmarks.md candidate 3) —
  listings rarely re-run within seconds.
- **AI-augmented features** (`chakshu`-style mime prediction,
  repo-context coloring) — 2.0 territory.
- **Windows.**
- **Configurable output via dotfiles or environment** — the CLI flag
  surface is the contract; environment-driven theming is the neofetch
  trap.

## Cross-references

- [`state.md`](state.md) — live status
- [`../../CHANGELOG.md`](../../CHANGELOG.md) — release history
- [`../audit/`](../audit/) — audit reports
- [darshana](https://github.com/MacCracken/darshana) — rendering substrate dep

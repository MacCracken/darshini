# darshini — Roadmap

> Forward-looking only. What shipped is in the
> [CHANGELOG](../../CHANGELOG.md); what is true right now is in
> [`state.md`](state.md). This file is the sequencing from here.

## Where we are

**v1.4.1** (2026-10-15). The v1.0 contract (M0–M10, shipped
2026-05-19 → 05-23) is intact: eza-style listing with long format,
multi-column layout, color, icons, tree mode, a git-status column and a
mime column, pipe-aware. The 1.x line since has added `--help` /
`--version` / `-F` / `-d` / multi-path / `--`, AGNOS as a target,
darshana's terminal primitives, two security sweeps
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
- **1.4.2** — internals + CI, zero output change:
  - **Sort on the stdlib.** Replace `render.cyr`'s merge sort with
    `vec_sort_by` (cycc 6.5.4; O(1) extra memory against the per-call
    scratch vec). Blocked until v1.4.1 because introsort is unstable
    and `str_lt_ci` called `README` / `readme` equal; v1.4.1's raw-byte
    tiebreak makes it a strict total order on distinct names, so the
    output cannot depend on stability any more. Verify by A/B and the
    40-entry merge test.
  - **CI runs the cross targets**, not just compiles them: the suite
    and the A/B matrix under `qemu-aarch64`, the suite under mirshi for
    agnos.
  - **CI table-drift gate**: `icons/default.cyml` vs `src/icons.cyr` and
    `mime/default.cyml` vs `src/mime.cyr`, entry by entry. ADR 0002
    deferred this "until drift becomes a problem"; v1.4.1 found the
    first drift (`xlsx`).
  - **Golden examples**: regenerate `docs/examples/` from the binary
    and check them in CI, so the doc can't show a layout darshini
    cannot produce again.

### 1.5.0 — `--git` accuracy (ADR 0005)

The column's answers change for many entries, so a minor bump and an
ADR, even though every change is a fix.

- **Full `.gitignore` semantics**, checked against
  `git status --ignored`: `!` negation with last-match-wins; `/`
  anchoring and mid-path patterns matched against the repo-relative
  path (not the basename); `?`, `[...]`, mid-pattern `*`, `**`;
  backslash escapes; git's trailing-space rule (and no leading-space
  trim). Today: exact name, `*suffix`, `name/` only.
- **Every ignore source**: nested `.gitignore` files scoped to their
  directory; `core.excludesFile` and `$XDG_CONFIG_HOME/git/ignore`.
- **Inheritance**: the contents of an ignored directory are `!`
  (`-T`, `darshini --git build`); today they show `?`.
- **`gitdir:` files** — submodules and linked worktrees: index from the
  gitdir, `info/exclude` via `commondir`. Declined since v1.4.1 (no
  column), which beats the wrong repo's index but is not an answer.
- **`.git` itself** in a listing shows `?`. Pick the right mark.
- **Ownership**: git's `safe.directory` rule — decline a repository
  owned by another user (a planted `/tmp/.git`).
- Considered, not planned: staged-vs-unstaged (needs HEAD's tree:
  object decompression); per-directory dirty aggregation (a stat of
  every tracked file below each directory).

### 1.6.0 — display correctness

- **Column widths in cells, not bytes.** The grid measures a name by
  bytes written, so well-formed multibyte names misalign the columns to
  their right (`é` 2 bytes / 1 cell, CJK 3 / 2). Needs UTF-8 decoding
  plus an East Asian Width table (wide = 2, combining = 0). TTY grid
  only; pipe output is unaffected.
- **Decorate path arguments** like listing entries on a TTY:
  `darshini *` colors and icons the directories' contents but prints
  the files it was handed plain. (`-F` on arguments landed in 1.4.1.)
- **One `-l` table across file arguments**: `darshini -l a b c` sizes
  each row on its own, so sizes don't line up as `ls -l` does.
- **`--mime` under `-T -l`** (ADR 0004 promised it; tree.cyr has no
  mime path).
- **mtime localization** — opt-in flag; UTC stays the default (the v1.0
  locale-free contract).

### 1.7.0 — platforms

- **aarch64 Linux, declared.** Output has matched x86_64 byte-for-byte
  since v1.4.0 (304 / 304 captures at v1.4.1). What remains is the
  owner's call plus the 1.4.2 CI gate.
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

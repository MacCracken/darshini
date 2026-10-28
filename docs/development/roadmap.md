# darshini — Roadmap

> Forward-looking only. What shipped is in the
> [CHANGELOG](../../CHANGELOG.md); what is true right now is in
> [`state.md`](state.md). This file is the sequencing from here.

## The 1.x rules

- **Frozen**: the flag surface, the pipe output bytes of a correct
  listing, the success / error exit classes, the icon-mapping format
  ([ADR 0002](../adr/0002-icon-format.md)), the color scheme
  ([ADR 0001](../adr/0001-color-scheme.md)), mime precedence
  ([ADR 0003](../adr/0003-mime-detection.md)), tree shape
  ([ADR 0004](../adr/0004-tree-mode.md)).
- **Breaking** (→ 2.0): a change to the exit code or default output
  bytes of a *correct* run (CLAUDE.md). Fixing output that was wrong —
  a lying `--git` column, a trailing pad, a raw control byte — is
  `Fixed`. Terminal-only presentation (color, icons, decoration — what
  no script reads) is `Changed`. A new opt-in flag is `Added`.
- **Bump size**: patch for fixes, internals, toolchain; minor for new
  flags, new targets, a large behavior delta in an existing column, or
  absorbing a breaking upstream (convention).

## Path

### 1.7.0 — behavior

Minor bump: `NO_COLOR` is new surface, and terminal `-l` output changes.

- **Symlink targets under `-l` on a terminal**: `link -> target`, as
  `ls -l` shows it (`-T -l` too). The target comes from `readlink` and
  is sanitized like a name ([SECURITY.md](../../SECURITY.md)). Pipe
  output stays name-only until 2.0 (below). `Added`.
- **Exit 1 when an entry can't be stat'd.** In a readable but
  unsearchable directory the `?` rows stay and the run exits 1, as
  `ls` does — the same class as an unreadable directory. `Fixed`.
- **`NO_COLOR`**: set and non-empty acts as `--no-color`
  ([no-color.org](https://no-color.org)). Nothing else from the
  environment: no `CLICOLOR` / `CLICOLOR_FORCE`, nothing that turns
  color on, icons unaffected. [ADR 0001](../adr/0001-color-scheme.md)
  gains the rule.
- **Directories get the folder icon** even when named like a file
  (`README.d`, `Makefile`), as eza does. Terminal-only;
  [ADR 0002](../adr/0002-icon-format.md)'s precedence changes.
  `Changed`.
- **Icon and mime tables generated from their CYML**
  ([`icons/`](../../icons/), [`mime/`](../../mime/)): a generator writes
  `src/icons.cyr` and `src/mime.cyr`, and CI regenerates and diffs
  (replacing `tests/table-drift.sh`'s comparison). Adding an icon
  becomes a CYML edit plus a regenerate — CLAUDE.md's "icon set is
  data" — with no runtime cost
  ([ADR 0002](../adr/0002-icon-format.md),
  [ADR 0003](../adr/0003-mime-detection.md)). Zero output change.

### 1.8.0 — platforms

- **aarch64 Linux, declared**: an aarch64 release asset in
  `release.yml`, and the docs naming it supported. Its output parity
  with x86_64 is already gated in CI ([state.md](state.md)).
- **AGNOS `lstat`** (#102, agnos 1.56.53): symlinks render as their
  target there. Changes agnos output; needs a
  [mirshi](https://github.com/MacCracken/mirshi) run proving #102 is
  emulated.
- **AGNOS decoration** (color, icons, the grid on the console): the
  per-fd test is agnos 1.57.13's `fd_kind#111`, which
  [darshana](https://github.com/MacCracken/darshana) 1.5.0's
  `tty_isatty` uses (darshini 1.6.1); `term_width` then takes the
  console size from `tty_winsize`. On older kernels, and under mirshi,
  `tty_isatty` still answers for the console, so `term_width` must stay
  0 there or `darshini > file` gets escapes. darshini needs a way to
  tell the two answers apart through darshana (CLAUDE.md: terminal
  queries go through darshana), which may mean a darshana request.
  Changes agnos terminal output. mirshi 1.11.3 has no #111, so the
  check is a real agnos boot, as darshana's `scripts/agnos-live.sh`
  does.

#### Waiting on upstream

Scheduled when the dependency lands, not before.

- **macOS / BSD**: needs [darshana](https://github.com/MacCracken/darshana)
  arms for `tty_winsize` / `tty_isatty`; the stdlib has the stat layouts
  and `getdirentries`.

### 2.0 — when it comes

- **Symlink targets on pipes too** (`-l`): the 1.7.0 terminal behavior
  becomes the default everywhere. Changes pipe bytes, hence 2.0.
- **`release.yml` accepts pre-release tags** (`2.0.0-rc1`), added with
  the first release candidate.

## Out of scope for 1.x

Kept so nobody adds these by accident.

- **Gitignore-aware filtering** — the `--git` column shows status, it
  doesn't filter. Filter with `find` or shell globs.
- **`--git` beyond [ADR 0005](../adr/0005-git-status-semantics.md)** —
  one status column (no staged / unstaged split), no per-directory
  aggregation, no `include` / `includeIf`, `GIT_DIR` / `GIT_WORK_TREE`
  or `core.ignoreCase`.
- **Extended attributes / ACLs.**
- **`--sort=size` / `--sort=mtime` / …** — alphabetical only. Reopen
  only on real demand.
- **Recursive `-R` (non-tree)** — use `-T --level N`.
- **Following symlinks into directories under `-T`** — would need a
  visited-inode set ([ADR 0004](../adr/0004-tree-mode.md)).
- **A mime magic cache** between runs
  ([benchmarks.md](../benchmarks.md) candidate 3) — listings rarely
  re-run within seconds.
- **AI-augmented features** (`chakshu`-style mime prediction,
  repo-context coloring) — 2.0 territory.
- **Windows.**
- **Configurable output via dotfiles or environment** — the CLI flag
  surface is the contract; environment-driven theming is the neofetch
  trap. The one exception is `NO_COLOR` (1.7.0), an off switch only.

## Cross-references

- [`state.md`](state.md) — live status, supported targets, features
- [`../../CHANGELOG.md`](../../CHANGELOG.md) — release history
- [`../adr/`](../adr/) — decisions:
  [0001 color scheme](../adr/0001-color-scheme.md) ·
  [0002 icon format](../adr/0002-icon-format.md) ·
  [0003 mime detection](../adr/0003-mime-detection.md) ·
  [0004 tree mode](../adr/0004-tree-mode.md) ·
  [0005 git status semantics](../adr/0005-git-status-semantics.md)
- [`../audit/`](../audit/) — audit reports
- [`../benchmarks.md`](../benchmarks.md) — hot-path measurements
- [darshana](https://github.com/MacCracken/darshana) — rendering substrate dep

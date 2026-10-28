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

No 1.x release is scheduled past 1.8.0: what remains waits on an
upstream change (below), and is scheduled when it lands.

### Waiting on upstream

Scheduled when the dependency lands, not before.

- **AGNOS decoration** (color, icons, the grid on the console) **and
  link targets there** (split out of 1.8.0, decided 2026-10-28). The
  per-fd test is agnos 1.57.13's `fd_kind#111`, which
  [darshana](https://github.com/MacCracken/darshana) 1.5.0's
  `tty_isatty` uses; `term_width` would then take the console size
  from `tty_winsize`, and `-l` would show targets as on Linux. But on
  older kernels, and under mirshi, `tty_isatty` answers for the
  console, so both must stay off there or `darshini > file` gets
  escapes and targets. Needs: a **public darshana probe** saying which
  answer `tty_isatty` gave (darshana has only the private
  `_agnos_has_tty_calls`; CLAUDE.md routes terminal queries through
  darshana). Changes agnos terminal output. Verified on a real kernel
  with `tests/agnos-live.sh` (mirshi 1.11.3 has no #110 / #111), whose
  console-segment checks then flip.
- **macOS / BSD**: needs [darshana](https://github.com/MacCracken/darshana)
  arms for `tty_winsize` / `tty_isatty`; the stdlib has the stat layouts
  and `getdirentries`.
- **AGNOS in CI**: mirshi 1.11.3 has no lstat#102, console_mode#110 or
  fd_kind#111, so the agnos runs under mirshi exercise only darshini's
  stat#33 fallback; the lstat path is checked by `tests/agnos-live.sh`
  as a release step. A mirshi that emulates #102 would let CI cover it.

### 2.0 — when it comes

- **Symlink targets on pipes too** (`-l`): 1.7.0's terminal behavior
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

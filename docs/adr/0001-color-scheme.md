# ADR 0001 — color scheme

**Status**: accepted
**Date**: 2026-05-22
**Milestone**: M4 (v0.5.0)

## Context

M4 lands per-entry color. The roadmap pins five categories
("dir, executable, symlink, broken symlink, regular file") and
defers the specific palette to this ADR. The picks below need
to render on the maintainer's daily-use targets — dark-background
xterm-class terminals — and stay readable when piped into
common renderers (less, tmux scrollback). The CLAUDE.md
hard-rule "no raw ANSI inline" means every escape routes
through darshana's `tty_sgr` / `tty_sgr_reset`; this ADR fixes
which SGR code each category gets.

The frozen palette ships as the v1.0 contract (roadmap M10);
flipping it after v1.0 is a breaking change. Picking the
8/16-color set, not 256 or 24-bit, keeps the contract narrow
and the palette terminal-agnostic.

## Decision

Eight categories, mapped to darshana's named-color constants.
Where darshini diverges from GNU `ls --color=auto`, it's noted.

| Category         | Detection                                     | SGR     | darshana constant         | Notes |
|------------------|-----------------------------------------------|---------|---------------------------|-------|
| Directory        | `S_IFDIR` (0x4000)                            | `34`    | `TTY_FG_BLUE`             | Matches `ls`'s default. |
| Symlink (live)   | `S_IFLNK` + follow-stat succeeds              | `36`    | `TTY_FG_CYAN`             | Matches `ls`. |
| Symlink (broken) | `S_IFLNK` + follow-stat fails                 | `31`    | `TTY_FG_RED`              | Matches `ls`. Single extra `stat(2)` per symlink — accepted cost. |
| Executable       | `S_IFREG` + any of `S_IXUSR|S_IXGRP|S_IXOTH`  | `32`    | `TTY_FG_GREEN`            | Matches `ls`. |
| FIFO             | `S_IFIFO` (0x1000)                            | `33`    | `TTY_FG_YELLOW`           | Matches `ls`. |
| Socket           | `S_IFSOCK` (0xC000)                           | `95`    | `TTY_FG_BRIGHT_MAGENTA`   | Matches `ls` (which uses bold magenta — close enough). |
| Block device     | `S_IFBLK` (0x6000)                            | `93`    | `TTY_FG_BRIGHT_YELLOW`    | Matches `ls`. |
| Character device | `S_IFCHR` (0x2000)                            | `93`    | `TTY_FG_BRIGHT_YELLOW`    | Matches `ls`. |
| Regular file     | `S_IFREG`, not executable                     | _none_  | (no SGR)                  | Default terminal color — leaves text alone. |

Wrap shape per colored entry:

```
CSI <code> m <name bytes> CSI 0 m
```

Both escape pairs route through `tty_sgr(code)` and
`tty_sgr_reset()` — three syscalls per colored entry. Acceptable
at typical directory sizes (< 1k entries); revisit at M9 (P(-1)
benchmark pass) if it shows up as a hot path.

### When color is on

- **TTY default**: stdout is a TTY (`ioctl(TIOCGWINSZ)` succeeds)
  AND `--no-color` was not passed.
- **Pipe default**: stdout is not a TTY → off (no escapes emitted
  at all — script consumers see plain bytes). Same gate as M3's
  single-column-on-pipe fallback.
- **`--no-color` override**: forces off even on a TTY. Long form
  only — no short form because the M10-frozen flag set keeps the
  short-letter space tight.
- `NO_COLOR` / `CLICOLOR` env-var honors aren't wired at M4.
  Defer to a follow-up; the `--no-color` flag covers the
  "force-off" case and the TTY-detection covers the
  "script-safe" case.

## Alternatives considered

- **8-color base only, no bright variants**. Cleaner contract.
  Rejected because socket / block / char dev all collapse into
  the same color (would have to drop the distinction). Matching
  `ls` is the higher priority.
- **256-color or 24-bit truecolor**. darshana ships the
  primitives; we declined. The 16-color palette is the
  lowest-common-denominator that renders correctly in
  serial consoles, tmux scrollback, screen readers, log
  archives, and dumb-terminal sessions. Truecolor is a v2
  consideration if [`chakshu`](https://github.com/MacCracken/chakshu)
  wires up repo-context-aware coloring.
- **Configurable via dotfile (`LS_COLORS`-style)**. Out of scope
  per roadmap ("Configurable output via dotfiles — the neofetch
  trap and we're not falling into it"). The flag surface is the
  contract.
- **Color regular files by extension** (e.g. `.md` magenta,
  `.cyr` blue, etc.). That's M5 territory (icons land per-
  extension via the CYML mapping). The mode-bit color scheme
  here stays orthogonal — M5 may add an extension-color column
  to the icons mapping or punt entirely.

## Consequences

- darshana becomes a hard dep (first non-stdlib entry in
  `[deps.*]`). Locked at 0.5.3 per cyrius.cyml. Bump policy
  follows shared-crates convention (refresh on every release).
- Each colored entry costs three writes (escape, name, reset).
  Sub-1k-entry directories are the common case; no batched-
  write optimization needed yet.
- Broken-symlink detection adds one `stat(2)` per symlink entry
  (over and above the always-present `lstat(2)` from the
  walk-with-color path). Symlinks are a small fraction of typical
  trees; cost is bounded.
- Padding math in `render_columns` / `render_long` is
  unchanged — `str_len` of the visible name is what's tracked,
  not byte-count-including-escapes. The escape sequences emit
  inline at write time and don't affect column alignment.

## References

- [roadmap.md M4](../development/roadmap.md) — "Color via darshana (v0.5.0)"
- [CLAUDE.md "Hard Constraints"](../../CLAUDE.md) — no raw ANSI inline
- [darshana ansi.cyr](https://github.com/MacCracken/darshana/blob/0.5.3/src/ansi.cyr) — primitive surface
- [GNU `ls` LS_COLORS defaults](https://www.gnu.org/software/coreutils/manual/html_node/General-output-formatting.html) — comparison baseline

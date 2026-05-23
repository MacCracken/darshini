# ADR 0004 — tree mode

**Status**: accepted (back-filled during M9 audit)
**Date**: 2026-05-23 (originally shipped 2026-05-23 in v0.7.0)
**Milestone**: M6 (v0.7.0)

## Context

M6 landed `-T` / `--tree` + `--level N`. The implementation
shipped without a contemporaneous ADR; CLAUDE.md's P(-1)
checklist names "tree-mode ADR" alongside color-scheme + icon-
format ADRs, so this back-fill closes the gap before v1.0
freeze.

This ADR locks in the v0.7.0 decisions so they're queryable
without source-spelunking; it documents existing behavior
rather than proposing new design.

## Decision

### Connector character set

Unicode box-drawing characters (U+2500 family):

| Glyph | Codepoint | UTF-8         | Position |
|-------|-----------|---------------|----------|
| `├`   | U+251C    | `e2 94 9c`    | Non-last sibling in current branch |
| `└`   | U+2514    | `e2 94 94`    | Last sibling in current branch |
| `─`   | U+2500    | `e2 94 80`    | Horizontal lead-in (two used per connector) |
| `│`   | U+2502    | `e2 94 82`    | Continuing ancestor (more siblings remain) |
| (4 spaces) | —    | `20 20 20 20` | Finished ancestor (no more siblings) |

Display widths: connector is 4 cells (`├──` 3 cells + 1 space)
or 4 spaces. Continuing-ancestor pipe is 1 + 3 spaces = 4
cells. Constant 4-cell-per-depth indent.

No ASCII fallback at v1.0. `tree(1)` ships `--charset=ascii`
for dumb-terminal users; darshini deliberately doesn't. The
box-drawing chars render correctly in any modern UTF-8
terminal (xterm, gnome-terminal, konsole, ghostty, alacritty,
kitty, wezterm, foot, all macOS/Windows terminals from the
last ~10 years). Deferred to post-v1 if a serial-console user
asks.

### Recursion contract

- Depth 0 = the user-supplied root (emitted as one line, no
  connectors).
- Children of depth `d` are at depth `d+1`.
- `--level N` caps the recursion at depth `N` (children visible,
  grandchildren under those leaves are not). Without `--level`,
  recurses unbounded.
- **Does NOT follow symlinks-to-dirs.** Symlinks render as
  themselves (cyan or red broken-symlink color per ADR 0001),
  but darshini does not descend into them. Matches `tree(1)`
  and `eza --tree` defaults. An opt-in follow flag is OUT for
  v1.0 — not on the M10 frozen list.
- Entries are sorted case-insensitively per directory (M1's
  sort_entries reused).

### Composition rules

Tree mode bypasses the column / single-column dispatch. Every
line is one entry. It composes with:

- `-l`: long-format prefix (perms / size / mtime) emitted
  before the connectors. Layout per row:
  `<perms> <size> <mtime> <ancestor-prefix><connector><git><icon><name>`
- `-h`: human-size formatting within the `-l` prefix.
- `--git` / `--mime`: status / mime decoration emitted per
  entry (mime only when `-l` also set, per ADR 0003).
- `--no-color` / `--no-icons`: suppression per the M4/M5 ADRs.
- `-1`: no-op under `-T` (tree is already
  one-entry-per-line); doesn't error to keep bundling forgiving.

### Depth-state representation

A `vec<i64>` depth-stack tracked through recursion. Slot value
1 = "more siblings remain at this depth" (renders `│   `);
slot 0 = "this depth is finished" (renders 4 spaces). Pushed
on entering each subdirectory recursion; popped on return.

Slot value pushed for a child-recursion is `(1 - is_last)` of
the parent entry — clean LIFO bookkeeping with no auxiliary
state.

### Per-row testable surface

`_tree_prefix_buf` and `_tree_connector_buf` write the byte
sequences into a caller-provided buffer rather than directly to
stdout. Tests assert exact bytes (the `e2 94 9c` etc. constants
in `tests/darshini.tcyr`). The stdout-emitting variants
(`_tree_emit_prefix` / `_tree_emit_connector`) are thin wrappers
that call the buf variants then `sys_write`.

## Alternatives considered

- **ASCII fallback (`--ascii` flag)**. Out for v1.0; defer
  if a downstream asks.
- **Follow symlinks-to-dirs by default**. Rejected — risks
  infinite loops on circular symlinks and surprises users
  coming from `tree(1)`.
- **Column-major fill (`tree`'s `-x` equivalent)**. Tree's
  vertical-then-horizontal nature makes this nonsensical;
  not applicable.
- **Per-subtree max-width for size column under `-l -T`**.
  Considered for M6; rejected as over-engineering. Each row
  emits its natural-width size; the tree's vertical structure
  provides visual rhythm without strict alignment.
- **`-I` glob filter for tree** (eza supports). Out per the
  v1.0 out-of-scope "Gitignore-aware filtering" line of
  reasoning.

## Consequences

- Tree mode adds one module (`src/tree.cyr`) and one bench
  none of the existing emit paths touch. Maintenance cost
  scales with the recursion-state bookkeeping, which is
  localized.
- The 4-cell-per-depth indent means a 10-deep tree consumes
  40 columns just for prefixes. On a 80-column terminal that
  leaves 40 cells for the entry name + decoration. Acceptable
  for typical project depths.
- No symlink-loop guard needed because we don't follow
  symlinks. If post-v1 adds a follow flag, a visited-inode set
  becomes required.

## References

- [roadmap.md M6](../development/roadmap.md) — "Tree mode (v0.7.0)"
- [CLAUDE.md P(-1) Documentation audit](../../CLAUDE.md) — "tree-mode ADR" line item that prompted this back-fill
- [2026-05-23 audit](../audit/2026-05-23-audit.md) — Step 6 documentation audit findings
- `tree(1)` `--charset=ascii` — ASCII-fallback option we chose not to mirror

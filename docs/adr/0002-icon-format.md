# ADR 0002 — icon format

**Status**: accepted
**Date**: 2026-05-22
**Milestone**: M5 (v0.6.0)

## Context

M5 lands per-entry icons. The roadmap fixes the shape:
> CYML icon mapping: `icons/default.cyml` maps `<ext>` → `<glyph>`
> + ANSI color, with special-case entries for well-known filenames
> (`Makefile`, `Dockerfile`, `README*`, etc.)

This ADR fixes:
1. The CYML schema — what tables, what keys, what values
2. The lookup priority (when an entry matches multiple rules)
3. The display-width assumption (per terminal-cell budget)
4. The font assumption (which Nerd Font subset users must have)
5. Whether `icons/default.cyml` is parsed at runtime or compile-baked
6. The color story — does the icon take the name's mode color, its
   own per-icon override, or something else?

## Decision

### Schema (`icons/default.cyml`)

Three tables, each maps a string key to a UTF-8 glyph. Optional
per-icon color override deferred — every icon takes the name's
mode color per ADR 0001. (Per-icon-color is a v1.1 candidate if
downstream asks.)

```cyml
[filenames]
# Exact-match (case-sensitive). Whole-basename match.
Makefile = "<glyph>"
Dockerfile = "<glyph>"
LICENSE = "<glyph>"
VERSION = "<glyph>"

[filename_prefixes]
# Case-sensitive prefix match. README* covers README, README.md, README.rst, …
README = "<glyph>"
CHANGELOG = "<glyph>"

[extensions]
# Lowercase extension after the last dot. `.tar.gz` matches `gz`.
cyr = "<glyph>"
md = "<glyph>"
…
```

Reserved future tables (not used at v1.0; documented to avoid
future-conflict): `[regex]` (NOT planned — gitignore-style globbing
is out per the v1.0 out-of-scope list), `[icon_colors]`
(per-icon color override — v1.1 if asked).

### Lookup priority

When deciding the icon for an entry named `name` with mode `m`,
walk this list. First match wins; no fallthrough.

0. **Directory** (v1.7.0) — a directory gets the folder glyph,
   whatever its name. Only directories: every other type still
   checks the name rules first.
1. **Exact filename** — `[filenames][name]`
2. **Filename prefix** — `[filename_prefixes][p]` for the first
   `p` (in table order) that is a prefix of `name`. No two shipped
   prefixes overlap, so first-match and longest-match agree today; a
   new prefix that nests inside an existing one must go above it.
3. **File-type override** — if `m` is a symlink / fifo / socket /
   blockdev / chardev, use the type-specific glyph (link, etc.).
   Regular files fall through to (4).
4. **Extension** — `[extensions][ext]` for the substring of
   `name` after the last `.` (lowercased)
5. **Generic fallback** — `<file glyph>` for any other regular
   file

The exact-filename + prefix rules sit above type-override so
`Makefile` (a regular file) gets its specific glyph rather than
the generic file glyph. Through v1.6.1 that put them above
directories too: a *directory* named `README.d` or `Makefile`
matched step 1 or 2 and got the README / Makefile glyph — the
opposite of eza (the v1.0 text claimed otherwise; corrected at
v1.4.1). Decided 2026-10-15 and shipped in v1.7.0: step 0, the
folder glyph wins for directories. The other types keep the name
rules first, so a symlink named `README` (a common
`README -> docs/README.md`) keeps the README glyph; its type shows
in its cyan color.

### Display width

Every icon takes **2 display cells**: the glyph itself (rendered
as 1 cell in Nerd-Font-aware terminals) followed by a single
space separator before the name. Byte length varies (3–4 UTF-8
bytes per glyph) but display width is fixed across the palette.

Column-fit math (`pick_cols`, `_columns_total_width`) gets a
fixed `icon_offset = 2` added to each entry's effective width
when icons are enabled. The padding diff between entries is
unchanged (icon_offset is uniform).

### Font assumption

**Nerd Font v3+** (any patched font). Codepoints used draw from
Devicons (U+E600–U+E8EF), Material Design Icons (U+F0000+),
Font Awesome (U+F000–U+F2FF), and Octicons (U+F400+). Terminals
without a Nerd Font installed will render boxes / replacement
characters. The `--no-icons` flag exists for that case;
documenting in README's Installation section.

There's no auto-detection for "is a Nerd Font installed?" — that
would require a per-terminal query escape sequence that not all
terminals support. The default-on / `--no-icons`-to-disable
contract puts the responsibility on the user.

### Compile-baked vs runtime CYML parse

The mapping is **compile-baked**: `icons/default.cyml` is the
source of truth and is **not** read at runtime. Since v1.7.0 its
three tables are generated into `src/icons_table.cyr` by
`tests/gen-tables.sh` (sh + POSIX awk, no toolchain) and
committed; `src/icons.cyr` keeps the lookup chain, the type
overrides and the fallback glyph. Through v1.6.1 the tables were
hand-copied into `src/icons.cyr` (v0.6.0's decision, below).

Why bake:

- Zero startup parse cost. `lib/cyml.cyr` parsing happens on
  every invocation — `darshini` is a hot daily-use tool that
  needs to start instantly.
- Fewer moving parts. No file I/O at startup means no
  `--icons-file=PATH` flag to bikeshed, no missing-file error
  paths to test, no parse-error reporting at startup.
- Smaller binary. The compile-baked lookup is a chain of
  `if (streq(...))` calls — Cyrius's DCE strips unused branches.

Why ship the CYML anyway:

- It's the schema spec, and since v1.7.0 the input: adding an icon
  is a CYML edit plus `sh tests/gen-tables.sh icons >
  src/icons_table.cyr`. The generator refuses what it cannot
  represent exactly (a key outside `[A-Za-z0-9._+-]`, an uppercase
  extension, a backslash in a value, a duplicate key, an entry in a
  table no lookup reads) instead of escaping it.
- It pre-stages runtime CYML loading. If v1.1+ ever adds
  `--icons-file=PATH` (user-supplied mapping), the parser
  contract is already documented and the schema is already
  fixed.

Keeping the two in sync was human-enforced from M5, then checked
by `tests/table-drift.sh` from v1.4.2 (v1.4.1 found the first
drift, `xlsx`). Since v1.7.0 CI regenerates the table and fails
on any difference, so a CYML edit without a regenerate, or a hand
edit of the generated file, cannot merge.

### Color

Per ADR 0001 — the icon takes the name's mode color. So a
directory's folder glyph renders blue, a markdown file's
glyph renders default (regular non-executable). No per-icon
color overrides at v1.0.

## Alternatives considered

- **Runtime CYML parse**. Rejected per "Compile-baked vs
  runtime" above.
- **Embed mapping as `#ref` directive**. The Cyrius `#ref`
  directive (per cyrius-guide.md) reads a CYML/TOML file at
  compile time and emits global vars. Tempted to use it but
  the global-var shape doesn't fit our nested
  `[filenames]` / `[extensions]` tables cleanly — would need
  a flat naming scheme like `ICON_EXT_cyr = "..."`. Punted
  for v0.6.0; reconsider for v1.1 if `icons.cyr` grows past
  a hundred entries and the manual mirroring gets brittle.
- **Per-icon color overrides**. eza supports them via
  `LS_COLORS`-style env. Out of scope at v1.0 per the
  ADR-0001 frozen palette; reconsider for v1.1.
- **Width 1 icons (no trailing space)**. Tempting for
  density but the space is needed for readability in
  multi-column layouts — without it, the icon merges
  visually with the name. eza uses 2 cells; matching.
- **Auto-detect Nerd Font availability**. Requires terminal
  query escapes that not all terminals support. The
  `--no-icons` flag is the documented fallback. Acceptable.

## Consequences

- Adding an icon is a data edit (CLAUDE.md "icon set is data"):
  the CYML, then a regenerate; CI checks the generated file. Until
  v1.7.0 it meant editing `icons/default.cyml` and `src/icons.cyr`
  in lockstep.
- Terminals without Nerd Fonts show replacement characters.
  Documented in README; mitigated by `--no-icons`.
- Column-fit math gets a `+ 2 * icons_enabled` adjustment per
  cell. Same total-width formula otherwise.
- Lookup is O(N) in the table size (string compare chain).
  At < 50 entries this is dwarfed by I/O cost; not a hot path.
  If the table grows past ~200 we should switch to a hashmap
  (probably tied to runtime-CYML-parse landing in v1.1).

## References

- [CHANGELOG 0.6.0](../../CHANGELOG.md) — M5: icons via CYML mapping
- [ADR 0001 color scheme](0001-color-scheme.md) — palette
  + mode-derived color shared with M5
- [Nerd Fonts v3 codepoints](https://www.nerdfonts.com/cheat-sheet) — glyph reference
- [eza icon set](https://github.com/eza-community/eza) — comparison baseline for the lookup precedence

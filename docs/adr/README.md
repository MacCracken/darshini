# Architecture Decision Records

Decisions about darshini — what we chose, the context, and the consequences we accept. Use these when a future reader would reasonably ask *"why did we do it this way?"*

## Conventions

- **Filename**: `NNNN-kebab-case-title.md`, zero-padded to four digits. Never renumber.
- **One decision per ADR.** If a decision supersedes a prior one, add a new ADR and set the old one's status to `Superseded by NNNN`.
- **Status lifecycle**: `Proposed` → `Accepted` → (optionally) `Superseded` or `Deprecated`.
- Use [`template.md`](template.md) as the starting point.

## ADR vs. architecture note vs. guide

| Kind | Lives in | Answers |
|---|---|---|
| ADR | `docs/adr/` | *Why did we choose X over Y?* |
| Architecture note | `docs/architecture/` | *What non-obvious constraint is true about the code?* |
| Guide | `docs/guides/` | *How do I do X?* |

## Index

| ADR | Decision | Status |
|---|---|---|
| [0001 — color scheme](0001-color-scheme.md) | Entry color is derived from the stat mode bits alone, mapped to darshana SGR codes. No `LS_COLORS`, no per-extension palette, no user-configurable theme. | accepted |
| [0002 — icon format](0002-icon-format.md) | The icon mapping is authored as CYML in `icons/default.cyml` but **compile-baked** into `src/icons.cyr`; the CYML is the human-readable spec, not a file the binary reads at runtime. Adding an icon means editing both. | accepted |
| [0003 — mime type detection](0003-mime-detection.md) | `--mime` resolves through a fixed precedence chain — inode type, then exact filename, then extension, then executable bit, then magic bytes — rather than consulting a system mime database. | accepted |
| [0004 — tree mode](0004-tree-mode.md) | `-T` renders a `tree(1)`-shaped recursion driven by a depth-stack of sibling flags, opt-in rather than default, and does not follow symlinks into directories. | accepted (back-filled during the M9 audit) |

Corrected at v1.3.2: this index read "_No ADRs yet_" from v0.1.0 through
v1.3.1 while all four ADRs sat beside it. The set was correctly indexed in
[`../guides/getting-started.md`](../guides/getting-started.md), the README, and
the roadmap the whole time, so nothing downstream was wrong — but the file a
reader opens *first* when looking for the ADR set was the one lying.

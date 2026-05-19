# darshini — Claude Code Instructions

> **Core rule**: this file is **preferences, process, and procedures** —
> durable rules that change rarely. Volatile state (current version,
> module line counts, supported backends, test counts, dep-gap status,
> consumers) lives in [`docs/development/state.md`](docs/development/state.md).
> Do not inline state here.

## Project Identity

**darshini** (Sanskrit दर्शिनी — *she who shows / displays*) — `eza`-equivalent pretty file listing for AGNOS. Colors, icons, git-status column, tree view, mime-type recognition.

- **Type**: Binary
- **License**: GPL-3.0-only
- **Language**: Cyrius (toolchain pinned in `cyrius.cyml [package].cyrius`)
- **Version**: `VERSION` at the project root is the source of truth — do not inline the number here
- **Genesis repo**: [agnosticos](https://github.com/MacCracken/agnosticos)
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md) · [First-Party Documentation](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md)
- **Shared crates registry**: [shared-crates.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/shared-crates.md)

## Goal

Own the fancy-listing lane in AGNOS userland — the human-eyes-on-iron file display, alongside [`kriya`](https://github.com/MacCracken/kriya)'s minimal `ls` (which handles scripts and pipes). Second member of the terminal-aesthetics set (commandress / **darshini** / hapi / BannerManor / iam). Natural producer/consumer pair with [`darshana`](https://github.com/MacCracken/darshana) — same Sanskrit root, darshana provides TTY/ANSI/cursor primitives, darshini renders against them.

## Current State

> Volatile state lives in [`docs/development/state.md`](docs/development/state.md) —
> current version, supported features, in-flight work, consumers,
> dep gaps. Refreshed every release.

This file (`CLAUDE.md`) is durable rules.

## Scaffolding

Project was scaffolded with `cyrius init darshini`. **Do not manually create project structure** — use the tools. If the tools are missing something, fix the tools.

## Quick Start

```sh
cyrius deps                              # resolve stdlib + darshana
cyrius build src/main.cyr build/darshini # compile
./build/darshini                          # prints scaffold version line
cyrius test                               # run tests/*.tcyr
```

## Key Principles

- **Sibling, not replacement.** `kriya`'s `ls` is canonical for scripts and pipes; darshini is for human eyes on TTY. Both ship. Don't try to subsume kriya.
- **Pipe-aware by default.** Auto-detect TTY. On a pipe, behave like minimal `ls` — one entry per line, no color, no icons. Surprising a script consumer is a bug.
- **darshana owns rendering primitives.** Every ANSI sequence, every cursor move, every termios change routes through `darshana`. No raw ANSI in the codebase.
- **Icon set is data.** CYML mapping `<ext>` → `<icon glyph>` ships in `icons/`. New icons are data edits, not code edits.
- **Single-pass render.** Walk the directory once, stat once, render once. No multi-pass layout, no preview window, no incremental redraw. The user invokes; we walk; we render; we exit.
- **Tree mode is optional, not the default.** `ls`-shape is the default; `-T` / `--tree` is opt-in.
- **Git-status column is optional.** Skip when no `.git` is in the ancestor chain (no wasted stat).

## Rules (Hard Constraints)

- **Read the genesis repo's CLAUDE.md first** — [agnosticos/CLAUDE.md](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md)
- **Do not commit or push** — the user handles all git operations
- **Never use `gh` CLI** — use `curl` to the GitHub API only
- Do not skip tests before claiming changes work
- Do not use `sys_system()` or `exec_*` — directory walking + stat + render only
- Do not trust paths from arguments without bounds + `../`-traversal check (relevant when an arg points at a symlink chain that escapes the intended scope)
- Do not modify `lib/` files (vendored stdlib / dep symlinks managed by `cyrius deps`)
- Do not emit raw ANSI escape codes inline — always route via darshana
- Do not call `git` as a subprocess — git-status comes from reading `.git/` files directly (no exec dependency)
- Do not hardcode toolchain versions in CI YAML — `cyrius = "X.Y.Z"` in `cyrius.cyml` is the source of truth

## Process

### P(-1): Hardening (before v0.2.0 first feature cut, and before v1.0)

1. **Cleanliness** — `cyrius build`, `cyrius lint`, tests pass
2. **Benchmark baseline** — `cyrius bench` for directory walk + render on a representative tree
3. **Internal review** — directory-walk bounds, stat error handling, output buffer sizing
4. **External research** — eza feature set; specifically what to deliberately *not* port (gitignore-aware filtering, extended attrs, etc. — gauge with the user)
5. **Security audit** — file findings in `docs/audit/YYYY-MM-DD-audit.md`
6. **Documentation audit** — icon-format ADR, color-scheme ADR, tree-mode ADR

### Work Loop (continuous)

1. **Work phase** — new column, new flag, new icon, bug fix
2. **Build check** — `cyrius build src/main.cyr build/darshini`
3. **Test additions** — happy + pipe + empty-dir + permission-denied + symlink-loop paths
4. **Internal review** — bounds, ANSI routing through darshana, stat returns
5. **Documentation** — CHANGELOG, state.md, guide if a new flag landed
6. **Version sync** — `VERSION`, `cyrius.cyml`, CHANGELOG header in sync before tag

### Task Sizing

- **Low/Medium effort**: batch — multiple flags or icon additions per cycle
- **Large effort**: small bites — git-status column, tree mode, mime-type each get their own M
- **If unsure**: treat it as large

## Cyrius Conventions

- All struct fields are 8 bytes (`i64`), accessed via `load64`/`store64` with offset
- Heap allocation via `fl_alloc()`/`fl_free()` for individual-lifetime data (per-entry stat results)
- Bump allocation via `alloc()` for long-lived data (directory entries vec)
- Enum values for constants — don't consume `gvar_toks` slots
- `break` in while loops with `var` declarations is unreliable — use flag + `continue`
- See [cyrius CLAUDE.md](https://github.com/MacCracken/cyrius/blob/main/CLAUDE.md) for the full convention set

## Docs

- [`docs/adr/`](docs/adr/) — Architecture Decision Records (*why X over Y?*)
- [`docs/architecture/`](docs/architecture/) — Non-obvious constraints
- [`docs/guides/`](docs/guides/) — Task-oriented how-tos (CLI usage, icon authoring)
- [`docs/examples/`](docs/examples/) — Sample outputs
- [`docs/development/state.md`](docs/development/state.md) — Live state snapshot
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — Milestones through v1.0
- `icons/` — CYML icon mapping shipped in-tree

Full doc-tree convention: [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md).

## CHANGELOG Format

Follow [Keep a Changelog](https://keepachangelog.com/). CLI-flag changes that alter exit codes or default-output bytes are `Breaking`. New flags + icons go under `Added`. Color-scheme changes are `Changed` (cosmetic-only).

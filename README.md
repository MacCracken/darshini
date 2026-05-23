# darshini

`eza`-equivalent pretty file listing — colors, icons, git-status
column, tree view, mime-type recognition — in
[Cyrius](https://github.com/MacCracken/cyrius).

**Sanskrit दर्शिनी** — *she who shows / displays*. Natural pair with
[`darshana`](https://github.com/MacCracken/darshana) (the TTY/raw-mode
primitives library) — same root, producer / consumer relationship.

## Not competing with kriya

[`kriya`](https://github.com/MacCracken/kriya) is BusyBox-style minimum
viable: `ls`/`mv`/`rm`/`find`/`grep` in one dispatcher.

`darshini` is the **fancy lane** — meant to coexist:

- `ls` (from `kriya`) → scripts, pipes, machine consumers
- `darshini`         → human-eyes-on-iron, daily interactive use

Same shape as Linux `ls` vs `eza` — both ship, different aesthetic
goals.

## Positioning

Second member of the terminal-aesthetics set:

- [`commandress`](https://github.com/MacCracken/commandress) (`cmdrs`) — prompt rendering
- **`darshini`** — file listing display
- [`hapi`](https://github.com/MacCracken/hapi) — dotfile / symlink management
- [`BannerManor`](https://github.com/MacCracken/bannermanor) (`bnrmr`) — ASCII banner generation
- [`iam`](https://github.com/MacCracken/iam) — system info / login MOTD

## Shape vs eza

- Renders via [`darshana`](https://github.com/MacCracken/darshana)
  (termios / ANSI / cursor); same color substrate as
  [`cyim`](https://github.com/MacCracken/cyim) and
  [`chakshu`](https://github.com/MacCracken/chakshu).
- Possibly later: [`chakshu`](https://github.com/MacCracken/chakshu)
  (AI-augmented monitor) for mime-type prediction, repo-context-aware
  coloring.
- Icon set sourced from a CYML mapping rather than inline string
  tables.

## Status

**v1.1.2 stable.** v1.0 contract frozen
([ADR 0001](docs/adr/0001-color-scheme.md) /
[0002](docs/adr/0002-icon-format.md) /
[0003](docs/adr/0003-mime-detection.md) /
[0004](docs/adr/0004-tree-mode.md));
pre-v1 [audit cleared](docs/audit/2026-05-23-audit.md)
2026-05-23. v1.1 adds `--help` / `--version` / `-F` / `-d`
plus merge-sort + git-hashmap upgrades; v1.1.1 adds
multi-path argv; v1.1.2 ships the hot-path optimizations
from the [bench baseline](docs/benchmarks.md) (hybrid sort
+ pick_cols early-out + path_join buf reuse). All v1.1.x
additions non-breaking under the M10 freeze. Linux x86_64
only through 1.x.

Feature surface:

- **Basic listing** — `darshini` / `darshini <path>`,
  case-insensitive alphabetical, error-discriminated.
- **Long format** (`-l` / `-lh` / `-l <file>`) — aligned
  4-column `permissions size mtime name`, UTC.
- **Multi-column auto-layout** — bare `darshini` on a TTY
  packs entries into the widest fit
  (vertical-then-horizontal); `-1` forces single-column;
  pipe is single-column automatically.
- **Per-entry color** — dirs blue, executables green,
  symlinks cyan (broken red), fifos yellow, etc.
  `--no-color` forces plain.
- **Per-entry icons** — Nerd Font glyphs per file type /
  name / extension; human-readable mapping in
  `icons/default.cyml`. `--no-icons` for terminals
  without a Nerd Font.
- **Tree mode** (`-T` / `-T --level N` / `-lT`) —
  standard box-drawing connectors; composes with long +
  color + icons; doesn't follow symlinks-to-dirs.
- **`--git` status column** — `.`/`M`/`?`/`!` per entry,
  read directly from `.git/index` v2 + `.gitignore`
  (no `git` subprocess). Silent skip outside a repo.
- **`--mime` type column** — `text/markdown`,
  `application/x-cyrius`, `application/x-executable`,
  etc; human-readable mapping in `mime/default.cyml`.
  Shown only under `-l`.
- **`-F` classify** — POSIX trailing indicator: `/`
  directory, `*` executable, `@` symlink, `|` fifo,
  `=` socket.
- **`-d` list-dir-as-self** — emit the path as a single
  entry instead of listing its contents.
- **Multi-path** — `darshini dir1 dir2 dir3`. Errors first,
  then non-dirs (one section, no header), then dirs (each
  with `path:` header + blank between). Composes with all
  format flags.
- **`--help` / `--version`** — standard meta flags.

v1.2+ candidates: mtime localization, post-v1 platforms
(aarch64 Linux then macOS / BSD / Windows). See
[state.md → Next](docs/development/state.md).

## Build

```sh
cyrius deps                                  # resolve stdlib + darshana
cyrius build src/main.cyr build/darshini     # compile
./build/darshini                              # list the current directory
cyrius test                                   # run tests/*.tcyr (233 assertions)
cyrius bench tests/darshini.bcyr              # run perf benches
```

Requires the [Cyrius](https://github.com/MacCracken/cyrius)
toolchain on PATH; the version is pinned in `cyrius.cyml`.

## Install

```sh
cp build/darshini ~/.local/bin/                       # or wherever your PATH points
darshini --version                                     # → "darshini 1.1.2"
```

Suggested zsh aliases (the maintainer's
`~/.config/zsh/.aliases.zsh`):

```zsh
alias ll='darshini -l --git'
alias l='darshini'
alias lfiles='darshini -F'
alias llfiles='darshini -lF --git'
alias ldir='darshini -d */'
alias lldir='darshini -ld */'
```

## Usage

```sh
darshini                       # multi-column, colored, icons (on TTY)
darshini -l                    # long format
darshini -lh                   # + human-readable sizes
darshini -lhT --level 2        # + tree view, depth 2
darshini -l --git              # + git status column (silent outside a repo)
darshini -l --git --mime       # + mime types
darshini src tests docs        # multi-path, each dir gets a header
darshini -d */                 # list each subdirectory as itself
darshini --no-color --no-icons # plain output
darshini | cat                 # pipe-aware: one entry per line, plain bytes
darshini --help                # full flag reference
```

## Documentation

- [`docs/adr/`](docs/adr/) — frozen design decisions (color
  scheme, icon format, mime detection, tree mode)
- [`docs/audit/2026-05-23-audit.md`](docs/audit/2026-05-23-audit.md)
  — pre-v1 security + code review
- [`docs/benchmarks.md`](docs/benchmarks.md) — perf baseline +
  v1.1.x optimization history
- [`docs/development/state.md`](docs/development/state.md) —
  live state (version, dep graph, known gotchas)
- [`docs/development/roadmap.md`](docs/development/roadmap.md) —
  milestone sequencing (v1.0 complete; 1.x section tracks
  ongoing)
- [`docs/guides/getting-started.md`](docs/guides/getting-started.md) —
  contributor walkthrough

## License

GPL-3.0-only

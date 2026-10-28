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

**v1.6.0 stable** — current state in
[state.md](docs/development/state.md), the plan in
[roadmap.md](docs/development/roadmap.md). v1.0 contract frozen
([ADR 0001](docs/adr/0001-color-scheme.md) /
[0002](docs/adr/0002-icon-format.md) /
[0003](docs/adr/0003-mime-detection.md) /
[0004](docs/adr/0004-tree-mode.md)); 1.x is non-breaking
additions, fixes and performance. Audits:
[2026-05-23](docs/audit/2026-05-23-audit.md) (pre-v1),
[2026-08-23](docs/audit/2026-08-23-audit.md),
[2026-10-15](docs/audit/2026-10-15-audit.md). Targets: Linux
x86_64 and AGNOS; the aarch64 build's output matches x86_64's
byte-for-byte but it is not yet a declared target. On a terminal,
untrusted names (and metadata) are neutralized before they reach the
screen (see [SECURITY.md](SECURITY.md)).

Feature surface:

- **Basic listing** — `darshini` / `darshini <path>`,
  case-insensitive alphabetical, error-discriminated.
- **Long format** (`-l` / `-lh` / `-l <file>`) — aligned
  4-column `permissions size mtime name`; mtimes in UTC, or in
  your zone with `--local-time` (TZ, else `/etc/localtime`). On a
  terminal a symlink shows `name -> target`, the target colored by
  what it points to; a pipe keeps name-only rows.
- **Multi-column auto-layout** — bare `darshini` on a TTY
  packs entries into the widest fit
  (vertical-then-horizontal), measuring names in terminal
  cells (CJK and emoji 2, combining marks 0); `-1` forces
  single-column; pipe is single-column automatically.
- **Per-entry color** — dirs blue, executables green,
  symlinks cyan (broken red), fifos yellow, etc.
  `--no-color`, or a non-empty `NO_COLOR`, forces plain.
- **Per-entry icons** — Nerd Font glyphs per file type /
  name / extension (a directory always gets the folder); the
  mapping is `icons/default.cyml`, compiled in from it.
  `--no-icons` for terminals without a Nerd Font.
- **Tree mode** (`-T` / `-T --level N` / `-lT`) —
  standard box-drawing connectors; composes with long +
  color + icons; doesn't follow symlinks-to-dirs.
- **`--git` status column** — `.`/`M`/`?`/`!` per entry,
  answering what `git status` would: the index (v2–v4, SHA-1
  or SHA-256) read directly — no `git` subprocess — and git's
  full ignore rules (a port of git's `wildmatch`) from every
  `.gitignore`, `info/exclude` and `core.excludesFile`, with
  an ignored directory's contents ignored. Submodules (by
  checked-out `HEAD`) and linked worktrees work; `.git` itself
  gets no mark. Silent outside a repo, and no column for an
  index it can't read or a repository owned by another user
  (git's `safe.directory`). See [ADR 0005](docs/adr/0005-git-status-semantics.md).
- **`--mime` type column** — `text/markdown`,
  `application/x-cyrius`, `application/x-executable`,
  etc; human-readable mapping in `mime/default.cyml`.
  Shown only under `-l`.
- **`-F` classify** — POSIX trailing indicator: `/`
  directory, `*` executable, `@` symlink, `|` fifo,
  `=` socket — on listing entries and path arguments alike.
- **`-d` list-dir-as-self** — emit the path as a single
  entry instead of listing its contents.
- **Multi-path** — `darshini dir1 dir2 dir3`. Errors first,
  then the non-directory arguments as one listing (decorated
  like any other — color, icons, `--git`, `-F`, the grid, one
  aligned `-l` table), then dirs (each with `path:` header +
  blank between). Composes with all format flags.
- **`--`** — end of flags, so `darshini -- *` is safe when a
  name starts with `-`.
- **`--help` / `--version`** — standard meta flags.
- **Exit status** — 0 on success; 1 when a path is missing or
  unreadable, a write fails, or (Linux) an entry the listing needs
  to stat can't be (`-l`, `-F`, `--git`, `--mime`, `-T` in an
  unsearchable directory — named on stderr, as `ls` does).

Next: see the [roadmap](docs/development/roadmap.md) — 1.8.0
platforms (aarch64 declared, AGNOS `lstat` and decoration).

## Build

```sh
cyrius deps                                  # resolve stdlib + darshana
cyrius build src/main.cyr build/darshini     # compile
./build/darshini                              # list the current directory
cyrius test                                   # run tests/*.tcyr (count: see state.md)
cyrius bench tests/darshini.bcyr              # run perf benches
```

Requires the [Cyrius](https://github.com/MacCracken/cyrius)
toolchain on PATH; the version is pinned in `cyrius.cyml`.

## Install

```sh
cp build/darshini ~/.local/bin/                       # or wherever your PATH points
darshini --version                                     # → "darshini 1.6.0"
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
darshini -l --local-time       # mtimes in your time zone (default UTC)
darshini -l --git              # + git status column (silent outside a repo)
darshini -l --git --mime       # + mime types
darshini src tests docs        # multi-path, each dir gets a header
darshini -d */                 # list each subdirectory as itself
darshini -F -- *               # classify every name, even ones starting with -
darshini --no-color --no-icons # plain output
darshini | cat                 # pipe-aware: one entry per line, plain bytes
darshini --help                # full flag reference
```

## Documentation

- [`docs/adr/`](docs/adr/) — frozen design decisions (color
  scheme, icon format, mime detection, tree mode)
- [`docs/audit/`](docs/audit/) — security + code reviews
  (pre-v1, v1.3.2, v1.4.1)
- [`docs/benchmarks.md`](docs/benchmarks.md) — perf baseline +
  optimization history (v1.1.x, v1.4.1, v1.4.2)
- [`docs/development/state.md`](docs/development/state.md) —
  live state (version, dep graph, known gotchas)
- [`docs/development/roadmap.md`](docs/development/roadmap.md) —
  the forward plan: next milestones, what is out of scope
- [`docs/guides/getting-started.md`](docs/guides/getting-started.md) —
  contributor walkthrough

## License

GPL-3.0-only

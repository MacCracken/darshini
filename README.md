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

Pre-1.0. v0.3.0 — M1 + M2 shipped:

- M1: basic listing — `darshini` / `darshini <path>`, alphabetical
  (case-insensitive), pipe-safe, error-discriminated.
- M2: long format + human sizes — `darshini -l` /
  `darshini -lh` / `darshini -l <file>`, aligned 4-column
  `permissions size mtime name`, IEC 1024-based size buckets
  under `-h`, mtime in UTC.

No multi-column layout, colors, icons, git column or tree mode
yet — those land M3–M7.

## Build

```sh
cyrius deps                                # resolve stdlib
cyrius build src/main.cyr build/darshini   # compile
./build/darshini                            # prints scaffold version line
cyrius test                                 # run tests/*.tcyr
```

## License

GPL-3.0-only

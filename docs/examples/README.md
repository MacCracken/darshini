# darshini — example output

Captured from the binary on a clean checkout of the darshini repo at
1.4.1 (generated, not hand-edited — the roadmap's 1.4.2 item
turns these into CI golden files). On a terminal, entries also carry
color and a Nerd Font glyph; the captures below use `--no-icons` /
`--no-color` where a glyph would not survive markdown, and say so.

## Default — multi-column on an 80-column TTY

```
$ darshini --no-icons --no-color
.git        CHANGELOG.md        cyrius.cyml  lib        SECURITY.md
.github     CLAUDE.md           cyrius.lock  LICENSE    src
.gitignore  CODE_OF_CONDUCT.md  docs         mime       tests
build       CONTRIBUTING.md     icons        README.md  VERSION
```

Vertical-then-horizontal fill, like `ls`. With icons each cell is two
cells wider, so the same listing may fit one column fewer. Dirs render
blue, executables green, symlinks cyan (broken: red).

## Long format with all decoration

```
$ darshini -l --git --mime | head -8
drwxr-xr-x   240 2026-10-15 17:34 inode/directory    ? .git
drwxr-xr-x    60 2026-10-15 17:34 inode/directory    . .github
-rw-r--r--    89 2026-05-19 19:03 text/x-gitignore   . .gitignore
drwxr-xr-x    60 2026-10-15 17:34 inode/directory    ! build
-rw-r--r-- 83378 2026-10-15 17:33 text/markdown      . CHANGELOG.md
-rw-r--r--  7923 2026-08-24 03:45 text/markdown      . CLAUDE.md
-rw-r--r--   181 2026-05-19 19:27 text/markdown      . CODE_OF_CONDUCT.md
-rw-r--r--  1733 2026-10-15 17:26 text/markdown      . CONTRIBUTING.md
```

...

Columns: perms / size / mtime (UTC) / mime / git status / name. Status:
`.` tracked and clean, `M` modified, `?` untracked, `!` ignored.

## Tree mode

```
$ darshini -T --level 2 docs
docs
├── adr
│   ├── 0001-color-scheme.md
│   ├── 0002-icon-format.md
│   ├── 0003-mime-detection.md
│   ├── 0004-tree-mode.md
│   ├── README.md
│   └── template.md
├── architecture
│   ├── 001-var-buf-is-bytes.md
│   ├── 002-agnos-fs-abi-split.md
│   ├── 003-allocation-lifetime-model.md
│   └── README.md
├── audit
│   ├── 2026-05-23-audit.md
│   ├── 2026-08-23-audit.md
│   └── 2026-10-15-audit.md
├── benchmarks.md
├── development
│   ├── roadmap.md
│   └── state.md
├── examples
│   ├── .gitkeep
│   └── README.md
└── guides
    └── getting-started.md
```

## Multi-path

```
$ darshini src tests
src:
cli.cyr
color.cyr
columns.cyr
git.cyr
icons.cyr
long.cyr
main.cyr
mime.cyr
render.cyr
test.cyr
tree.cyr
walk.cyr

tests:
darshini.bcyr
darshini.fcyr
darshini.tcyr
```

## Classify (`-F`)

```
$ darshini -F -1 . | head -6
.git/
.github/
.gitignore
build/
CHANGELOG.md
CLAUDE.md
```

```
$ darshini -dF docs src tests build/darshini
docs/
src/
tests/
build/darshini*
```

Off the grid, a name with no indicator ends at its last byte — no pad
space (v1.4.1).

## Pipe-aware (script-safe)

```
$ darshini | head -3
.git
.github
.gitignore
```

No color, no icons, no columns — same shape as minimal `ls`.

## Outside a git repo

```
$ darshini --git /usr | head -3
aarch64-linux-gnu
bin
include
```

`--git` silently skips when there's no `.git/` in the ancestor chain —
no error, no column.

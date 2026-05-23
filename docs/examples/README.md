# darshini — example output

Captured on the darshini repo itself at v1.1.2. Box-drawing
chars + Nerd Font glyphs are present in the actual TTY
output but render here as plain text (markdown can't
preview them faithfully).

## Default — multi-column on a TTY

```
$ darshini
.git        build         CODE_OF_CONDUCT.md  docs     README.md    tests
.github     CHANGELOG.md  CONTRIBUTING.md     icons    SECURITY.md  VERSION
.gitignore  CLAUDE.md     cyrius.cyml         lib      src
            cyrius.lock   LICENSE             mime
```

Dirs render blue; executables green; symlinks cyan
(broken: red); each entry prefixed with a Nerd Font glyph.

## Long format with all decoration

```
$ darshini -l --git --mime
drwxr-xr-x   128 2026-05-22 22:35 inode/directory   ? .git
drwxr-xr-x    18 2026-05-19 19:03 inode/directory   . .github
-rw-r--r--    89 2026-05-19 19:03 text/x-gitignore  . .gitignore
drwxr-xr-x    16 2026-05-23 02:49 inode/directory   ! build
-rw-r--r-- 26851 2026-05-23 02:40 text/markdown     . CHANGELOG.md
...
```

Columns: perms / size / mtime (UTC) / mime / git-status / name.

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
│   └── README.md
├── audit
│   └── 2026-05-23-audit.md
├── benchmarks.md
├── development
│   ├── roadmap.md
│   └── state.md
├── examples
│   └── README.md
└── guides
    └── getting-started.md
```

## Multi-path

```
$ darshini src tests
src:
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
$ darshini -dF docs src tests
docs/
src/
tests/
```

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
$ darshini --git /tmp | head -3
.font-unix
.ICE-unix
.X11-unix
```

`--git` silently skips when there's no `.git/` in the
ancestor chain — no error, no column.

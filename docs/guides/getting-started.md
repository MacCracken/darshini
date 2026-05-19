# Getting started with darshini

## Build

```sh
cyrius deps                              # resolve stdlib (+ darshana from M4)
cyrius build src/main.cyr build/darshini # compile
./build/darshini                          # prints scaffold version line
cyrius test                               # run tests/*.tcyr
```

## Layout

- `src/main.cyr` — entry point (currently scaffold; M1+ fills CLI dispatch)
- `tests/darshini.{tcyr,bcyr,fcyr}` — tests / benchmarks / fuzz

Once M1+ ships:

- `src/walk.cyr` — directory walking + stat
- `src/render.cyr` — line / column / tree formatting
- `src/color.cyr` — darshana ANSI routing
- `src/icons.cyr` — icon-mapping loader
- `src/tree.cyr` — recursive tree rendering
- `src/git.cyr` — `.git/`-direct status column
- `src/mime.cyr` — magic-bytes mime detector
- `icons/<name>.cyml` — icon mappings shipped in-tree

## Adding a feature

1. Identify the milestone (`docs/development/roadmap.md`) the feature
   belongs to. If it's outside the roadmap, propose an ADR first.
2. Edit / add the appropriate `src/<name>.cyr` module.
3. Add tests in `tests/darshini.tcyr` covering happy path + edge
   cases (empty dir, permission denied, symlink loop, broken UTF-8
   names — as relevant).
4. If the feature touches color or cursor positioning, route
   through `darshana`. **No raw ANSI escape codes in darshini.**
5. CHANGELOG entry. Mark `Breaking` if you alter default-output
   bytes or exit codes.

## Adding an icon

(Available at M5+.)

1. Edit `icons/default.cyml`.
2. Add a test case rendering a file with the trigger extension or
   filename in `tests/darshini.tcyr`.
3. CHANGELOG entry under `Added`.

## Pipe-awareness

darshini is pipe-aware by default. On a TTY, it produces multi-column,
colored output with icons. On a pipe (`darshini | cat`,
`darshini | grep ...`), it produces one entry per line, no color,
no icons — same as minimal `ls`. **Never surprise a script consumer.**

See [`../adr/template.md`](../adr/template.md) when a non-trivial
design choice deserves an ADR.

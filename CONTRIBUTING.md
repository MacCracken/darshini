# Contributing to darshini

Contributions are welcome. All contributions must be licensed under
GPL-3.0-only.

## Development

Follow the conventions in [`CLAUDE.md`](CLAUDE.md) and the AGNOS
[first-party standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md).

Build and test before submitting:

```sh
cyrius deps
cyrius build src/main.cyr build/darshini
cyrius test
```

## Before proposing a feature

darshini's scope is set by `docs/development/roadmap.md` and the
"Out of scope" list. Before opening a PR:

- Is this a feature **already** on the roadmap? Great — file the PR.
- Is this **explicitly out of scope** (gitignore-aware filtering,
  alternate sort orders, dotfile config)? Please open an issue
  for discussion first; v1.0 has hard boundaries.
- Is this an **icon** addition? Wait for M5 (icon mapping system).
- Is this for a **shell-script consumer** (machine-readable output)?
  Use `kriya`'s `ls` instead — darshini is for human eyes on TTY.

## Adding a feature

1. Identify the milestone the feature belongs to.
2. Implement the feature module.
3. Add happy + edge tests (empty dir, permission denied, symlink loop).
4. Route any ANSI / color through `darshana`. No raw escape codes.
5. CHANGELOG entry under `Added` (or `Breaking` if it alters
   default output).

## Reporting Issues

Open an issue at https://github.com/MacCracken/darshini/issues.

For security-sensitive issues (path traversal, ANSI injection via
crafted filenames), see [`SECURITY.md`](SECURITY.md).

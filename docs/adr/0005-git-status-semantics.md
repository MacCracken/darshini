# 0005 — `--git` answers what git answers: full ignore rules, every ignore source, worktrees and submodules

**Status**: Accepted
**Date**: 2026-10-15

## Context

M7 (v0.8.0) shipped the `--git` column with a deliberately small ignore
matcher: patterns from the repository-root `.gitignore` and
`.git/info/exclude` only, matched against an entry's basename, in three
shapes — exact name, `*suffix`, `name/`. The 1.4.1 audit fixed the index
side (v2–v4, SHA-256, the u32 compare, physical paths) and left the ignore
side for this release, because closing it changes the column's answer for
many entries at once. Measured against `git status` / `git check-ignore`,
the subset was wrong in both directions:

- **`!` where git says `?`** — files a user meant to commit, shown as
  ignored: negation (`*.log` + `!keep.log` left `keep.log` ignored); a
  leading `/` was stripped, so `/TODO` also matched `src/TODO`; leading
  spaces were trimmed.
- **`?` where git says `!`** — GitHub's stock Python template
  (`*.py[cod]`), `?`, mid-pattern `*`, `**`, escapes, path patterns
  (`docs/build`); every nested `.gitignore`; `core.excludesFile` and its
  default `$XDG_CONFIG_HOME/git/ignore`; the contents of an ignored
  directory.

And around the matcher: a submodule or linked worktree (`.git` is a
*file*) declined the column; a submodule's directory in its superproject
showed `M` (its gitlink's index mtime is 0); `.git` itself and, under
`-T`, everything inside it showed `?`; and nothing stopped a `.git`
planted in a shared parent directory (`/tmp/.git`) from applying to other
users' listings — git refuses that (`safe.directory`).

The hard rule stands: no `git` subprocess (CLAUDE.md). So the question is
how much of git to reimplement, and how to know it matches.

## Decision

**Reimplement git's rules exactly where the column depends on them, and
prove it differentially against git itself.**

1. **Pattern matching is a port of git's `wildmatch`** (`src/ignore.cyr`):
   `*`, `?`, `[...]` (ranges, `!`/`^` negation, POSIX `[:class:]`), `\`
   escapes, and `**` with git's `WM_PATHNAME` rules. A pattern with no
   `/` (after a trailing one is removed) matches the entry's basename at
   any depth below its `.gitignore`; a pattern with a `/` anywhere else is
   anchored to its `.gitignore`'s directory and matched against the path
   below it. A trailing `/` matches directories only (lstat, so a symlink
   to a directory is not one).
2. **Parsing follows git's `add_patterns_from_buffer`**: a UTF-8 BOM is
   skipped; one `\r` before each `\n` is dropped; a line starting with
   `#` is a comment (`\#` is a literal); trailing spaces are trimmed
   unless backslash-escaped; leading spaces are kept; `!` negates (`\!`
   is a literal).
3. **Every ignore source, in git's precedence**: the `.gitignore` in each
   directory from the entry's parent up to the worktree root (deepest
   first), then `$GIT_COMMON_DIR/info/exclude`, then `core.excludesFile`
   (default `$XDG_CONFIG_HOME/git/ignore`, else `~/.config/git/ignore`).
   Within one source the last matching pattern wins; the first source
   with any match decides. A `.gitignore` that is a symlink is not read
   (git ≥ 2.32 refuses them too).
4. **An excluded directory is final.** An untracked path below it is
   ignored, and no negation re-includes it — git's documented rule
   ("It is not possible to re-include a file if a parent directory of
   that file is excluded"). Directory verdicts are memoized per run.
5. **Tracked beats ignored**, as before and as in git.
6. **Directory marks**: `.` if any tracked path lies below it; else `!`
   if it is excluded (itself or an ancestor); else `?`. This includes the
   listing root (the `-T` root line, `-ld --git`), which v1.3.3 exempted
   from ignore matching — with inheritance that exemption would show `?`
   above a tree of `!`. Known divergence, kept: a directory whose
   untracked contents are *all* ignored, but which matches no pattern
   itself, shows `?` (git shows nothing for it); telling those apart
   needs a walk of the whole subtree per directory.
7. **`.git` and everything under it is not part of the worktree**: mark
   ` ` (blank). git reports nothing for those paths.
8. **Repository discovery follows `.git` files**: `gitdir: <path>`
   (relative to the file's directory) names the git dir, and
   `<gitdir>/commondir`, if present, the common dir of a linked
   worktree. The index comes from the git dir; config and
   `info/exclude` from the common dir.
9. **A gitlink (submodule) entry** is `.` when the submodule's checked-out
   `HEAD` (read through its own `.git` file, refs and `packed-refs`)
   equals the commit recorded in the index, `M` when it differs, and `.`
   when the submodule is not checked out (git shows nothing for it).
10. **Ownership**: on Linux the column is declined — no column, as for
    any unusable repository — when the worktree root, the `.git` file or
    the git dir is not owned by the effective uid (as root, by `SUDO_UID`
    when set), unless a protected `safe.directory` (system or global
    config, never the repository's own) is `*`, equals the worktree path,
    or is a `<path>/*` prefix of it. An empty value resets the list, as
    in git.
11. **Configuration**: a small git-config reader for exactly the keys
    above (`core.excludesFile`, `safe.directory`,
    `extensions.objectFormat`), reading `/etc/gitconfig` (unless
    `GIT_CONFIG_NOSYSTEM`), `$XDG_CONFIG_HOME/git/config`, `~/.gitconfig`,
    then the repository's common-dir `config`, later files winning. Not
    supported: `include` / `includeIf`, `GIT_DIR` / `GIT_WORK_TREE` /
    `GIT_CONFIG_GLOBAL`, `core.ignoreCase` (matching is case-sensitive),
    per-worktree `config.worktree`.

**Verification is part of the decision**: a differential harness builds
repositories with random patterns at several directory levels and random
trees, and requires darshini's `!` set to equal `git check-ignore`'s,
path for path (local, thousands of cases), and a fixed set of the tricky
cases runs in CI against the runner's git (`tests/git-parity.sh`).

## Consequences

- **Positive** — the column means what the user's git means. The stock
  Python, Node and Rust `.gitignore` templates, monorepos with nested
  ignore files, global ignores, worktrees and submodules all answer
  correctly; `-T --git` no longer lists `.git` internals as untracked.
- **Negative** — darshini now owns a port of `wildmatch` and a slice of
  git's config and discovery logic, and must track git if those change
  (they have been stable for years; the differential gate catches drift).
  `--git` costs one extra `lstat` + read per directory visited (each
  directory's `.gitignore`, cached) and reads up to four config files per
  run.
- **Neutral** — answers change for many entries; a minor release
  (1.5.0). Every change is toward git's answer. On AGNOS there is no
  `STAT_UID` and no `getcwd`, so ownership is not checked and `--git`
  still needs an absolute path there.

## Alternatives considered

- **Run `git status` / `git check-ignore`.** Exact by definition, and
  forbidden: CLAUDE.md's no-`git`-subprocess rule (no exec dependency,
  no process per listing).
- **Link libgit2.** No FFI in darshini (shared-stack rule), and a large
  dependency for a status column.
- **A simpler fnmatch-style matcher.** Would fix `*.py[cod]` but not `**`,
  anchoring or `WM_PATHNAME`'s `*`-stops-at-`/`; "almost git" is the bug
  this ADR closes.
- **Keep declining submodules and worktrees.** Honest, but no answer for
  common layouts; following `gitdir:` is a few dozen lines.
- **Aggregate directory status** (`M` on a directory holding a modified
  file; `!` for a directory whose contents are all ignored). Useful, but
  needs a stat of every tracked path below each directory or a subtree
  walk; considered and left out.

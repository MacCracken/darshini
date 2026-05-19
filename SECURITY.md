# Security Policy

## Threat surface

darshini walks directories and writes a rendered listing to stdout.
It does not spawn processes, open network sockets, or write to the
filesystem beyond standard output. The realistic threats:

- **Path-argument traversal** — `darshini ../../etc` is valid usage;
  darshini lists what it's pointed at. But path arguments still need
  bounds and symlink-loop detection so a crafted directory tree
  can't infinite-loop the walker.
- **ANSI injection via filenames** — a filename containing raw ANSI
  escape sequences could alter terminal state when displayed.
  darshini sanitizes entry names before rendering (substitutes a
  placeholder for control characters).
- **`.git/`-parsing safety** — when `--git` is enabled, darshini
  reads files under `.git/`. Bounded reads with format validation;
  refuse to parse `.git/` files larger than reasonable limits.
- **Symlink loops** — directory walks must terminate even on crafted
  symlink cycles. Default behavior: don't follow symlinks into
  directories during walk (only at the root).

## Reporting Vulnerabilities

Report vulnerabilities privately to **security@agnos.dev**. Do not
open public issues for security bugs.

We will acknowledge receipt within 48 hours and provide a timeline
for a fix.

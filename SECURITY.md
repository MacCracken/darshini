# Security Policy

## Threat surface

darshini walks directories and writes a rendered listing to stdout.
It does not spawn processes, open network sockets, or write to the
filesystem beyond standard output. The realistic threats:

- **Path-argument traversal** — `darshini ../../etc` is valid usage;
  darshini lists what it's pointed at. But path arguments still need
  bounds and symlink-loop detection so a crafted directory tree
  can't infinite-loop the walker.
- **ANSI injection via filenames** — a filename containing raw
  escape sequences can alter terminal state when displayed.
  **On a TTY**, darshini substitutes `?` for every C0 control byte
  (0x00–0x1f), DEL (0x7f), and the UTF-8 encoding of the C1 controls
  (0xC2 0x80–0x9F) — one `?` per byte, the shape `ls -q` uses. Bytes
  ≥ 0x80 are left alone, so UTF-8 filenames render intact.
  **On a pipe, entry names are written byte-for-byte**, matching
  `ls --quoting-style=literal`, so a script consumer receives a name
  it can actually open. A pipeline that renders untrusted names to a
  terminal is responsible for its own sanitization.

  This was **not** true before v1.3.2 — through v1.3.1 names went to
  the terminal raw in both cases, and this section claimed otherwise.
  See [`docs/audit/2026-08-23-audit.md`](docs/audit/2026-08-23-audit.md).
- **`.git/`-parsing safety** — when `--git` is enabled, darshini
  reads files under `.git/`. The index parser validates the header
  and bounds every entry against the buffer length. Reads are sized
  from `stat(2)` and capped: a `.git/index` beyond the ceiling is
  **declined** — the git column silently does not appear — rather
  than parsed truncated. Through v1.3.1 an oversized index WAS
  silently truncated, and every entry past the cutoff was reported
  untracked; that is fixed in v1.3.2.
- **Symlink loops** — directory walks must terminate even on crafted
  symlink cycles. Default behavior: don't follow symlinks into
  directories during walk (only at the root).

## Reporting Vulnerabilities

Report vulnerabilities privately to **security@agnos.dev**. Do not
open public issues for security bugs.

We will acknowledge receipt within 48 hours and provide a timeline
for a fix.

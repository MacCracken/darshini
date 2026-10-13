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
  escape sequences can alter terminal state when displayed, and so can
  a path argument (`darshini *` turns every name in a directory into
  one). **On a terminal**, every untrusted name or path darshini writes
  — listing entries, argv paths echoed as non-directories or by `-d`,
  the multi-path `<dir>:` header, the `-T` root, and paths quoted in
  error messages on stderr — goes through darshana's
  `tty_sanitize_buf` in `TTY_SANITIZE_UTF8` mode: each C0 control
  (0x00–0x1f), DEL (0x7f), C1 control written as UTF-8 (0xC2 0x80–0x9F),
  and byte that is not part of well-formed UTF-8 (including a raw
  0x80–0x9F, the 8-bit C1 range) becomes one `?`. Well-formed UTF-8
  renders intact. stdout and stderr are judged separately, so
  `darshini * > out.txt` still sanitizes the errors that reach the
  terminal.
  **On a pipe or file, names are written byte-for-byte**, matching
  `ls --quoting-style=literal`, so a script consumer receives a name
  it can actually open. A pipeline that renders untrusted names to a
  terminal is responsible for its own sanitization.
  **On AGNOS** there is no per-fd terminal test — darshana's
  `tty_isatty` there reports whether the console is up — so names are
  sanitized whenever the console is up, piped or not.

  History: before v1.3.2 names went to the terminal raw in every case
  (and this section claimed otherwise; see
  [`docs/audit/2026-08-23-audit.md`](docs/audit/2026-08-23-audit.md)).
  v1.3.2–v1.3.4 sanitized only what went through the listing writer
  (entries, the `-T` root, `-l` of a single path) — argv echoes, `-d`,
  the `<dir>:` header and error messages went out raw — passed raw C1
  and malformed UTF-8, and never sanitized on AGNOS. v1.4.0 closed all
  three.
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

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
  — listing entries, path arguments listed as non-directories or under `-d`,
  the multi-path `<dir>:` header, the `-T` root, a symlink's target
  under `-l` (v1.7.0, shown only on a terminal; `readlink`, nothing
  followed), and paths quoted in error messages on stderr, including
  each entry `-l` cannot stat (v1.7.0) — goes through darshana's
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
  **On AGNOS** the test is per-fd on agnos 1.57.13 and later (darshana
  1.5.0's `tty_isatty` asks `fd_kind#111`), so piped names go out
  byte-for-byte as on Linux. On older kernels (and under mirshi)
  `tty_isatty` reports whether the console is up, so names are
  sanitized whenever it is, piped or not. Decoration and link targets
  (v1.8.1) take the other direction: they appear only where darshana's
  `tty_isatty_is_per_fd()` says that answer is about the fd, so a
  redirected listing never carries escapes there.

  **Metadata is untrusted too.** A file's mtime survives extraction from
  a hostile archive (tar keeps it; tmpfs and btrfs store it). Through
  v1.4.0 a year past 9999 made `-l` emit arbitrary bytes from the
  date — `ESC 7` / `ESC 8` (save / restore cursor) among them — raw to
  the terminal, and made the date conversion loop for minutes per entry.
  Since v1.4.1 such an mtime renders as the `????-??-?? ??:??`
  placeholder (since v1.6.0 any date outside 0000..9999, after the
  `--local-time` offset). Sizes and modes are formatted from fixed
  alphabets. `--local-time` reads the zone file `TZ` names (under
  `$TZDIR` or `/usr/share/zoneinfo`, or an absolute path) or
  `/etc/localtime`: size-capped at 1 MB and parsed with every count
  and index bounds-checked; anything that is not a valid TZif file
  falls back to a POSIX rule string or UTC. darshini is not setuid, so
  `TZ` naming an arbitrary file reads nothing the user couldn't.

  History: before v1.3.2 names went to the terminal raw in every case
  (and this section claimed otherwise; see
  [`docs/audit/2026-08-23-audit.md`](docs/audit/2026-08-23-audit.md)).
  v1.3.2–v1.3.4 sanitized only what went through the listing writer
  (entries, the `-T` root, `-l` of a single path) — argv echoes, `-d`,
  the `<dir>:` header and error messages went out raw — passed raw C1
  and malformed UTF-8, and never sanitized on AGNOS. v1.4.0 closed all
  three.
- **`.git/`-parsing safety** — when `--git` is enabled, darshini
  reads files under `.git/`. The index parser (versions 2–4, SHA-1 or
  SHA-256) validates the header, bounds every entry against the buffer
  length, and requires each name to be non-empty and NUL-terminated
  where git puts the NUL. Reads are sized from `stat(2)` and capped. An
  index that exists but cannot be used — unreadable, beyond the
  ceiling, an unknown version, misframed — is **declined**: the git
  column silently does not appear rather than appearing with wrong
  answers. (That was claimed here before v1.4.1 but held only for the
  size ceiling: a parse failure was ignored and the column showed every
  file `?`. Through v1.3.1 an oversized index was silently truncated.)
  A `.git` *file* (submodule, linked worktree) is followed to its git
  dir (v1.5.0; v1.4.1 declined it) rather than falling through to the
  enclosing repository's index.
  **Ownership** (v1.5.0, Linux): like git, darshini declines — no
  column — a repository whose worktree root, `.git` file or git dir is
  not owned by the effective uid (as root: `$SUDO_UID`), unless
  `safe.directory` in the system or global config (never the
  repository's own) allows it. Through v1.4.2 a `.git` planted in a
  shared parent directory (`/tmp/.git`) applied to every other user's
  listings below it. Not checked on AGNOS (no owner in its stat).
  A `.gitignore` that is a symlink is not followed (git ≥ 2.32 refuses
  those too); `info/exclude` and `core.excludesFile` are read wherever
  they point. Config files are read from `/etc/gitconfig`,
  `$XDG_CONFIG_HOME/git/config`, `~/.gitconfig` and the repository —
  only the three keys ADR 0005 names, nothing executed.
- **Opens cannot hang** — every file darshini opens was classified by a
  stat first, but can be swapped (for a FIFO, say) before the open.
  Since v1.4.1 opens on Linux are non-blocking and close-on-exec, the
  mime probe does not follow symlinks, and an `fstat` must confirm a
  regular file before anything is read. Through v1.4.0 `--mime` over a
  directory being raced this way could block forever.
- **Symlink loops** — directory walks must terminate even on crafted
  symlink cycles. Default behavior: don't follow symlinks into
  directories during walk (only at the root).

## Reporting Vulnerabilities

Report vulnerabilities privately to **security@agnos.dev**. Do not
open public issues for security bugs.

We will acknowledge receipt within 48 hours and provide a timeline
for a fix.

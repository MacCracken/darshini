# 002 — the agnos filesystem ABI differs from Linux in four ways, and `walk.cyr` hides all of them

**Applies to**: `src/walk.cyr`, `src/columns.cyr`, `src/git.cyr`, `src/color.cyr`.
**Landed**: v1.3.0.

darshini builds for Linux x86_64 and for AGNOS from the same source. The
divergence is *not* a matter of different syscall numbers for the same calls —
the two ABIs disagree about the shape of the operations themselves. Everything
below is `#ifdef CYRIUS_TARGET_AGNOS`-gated so the Linux path stays
byte-identical.

**1. `stat` and `open` take an explicit path length on agnos.** Linux takes a
NUL-terminated cstr. The wrappers `d_stat` / `d_open_ro` / `d_lstat` in
`walk.cyr` exist solely to hide this; call them rather than the raw syscalls.

**2. There was no `lstat` on agnos** — syscall 6 is `close` there, not `lstat`.
`d_lstat` falls back to `d_stat`, so on agnos a symlink reports its target.
agnos has since grown `lstat#102` (agnos 1.56.53), which the stdlib wraps as
`sys_lstat(path, len, buf)`; adopting it changes how agnos renders symlinks and
is tracked in the roadmap, not done.
(Through v1.3.4 the Linux arm issued the literal 6 too, which is why the
`--aarch64` build rendered `?` for every stat-derived column — 6 is
`lsetxattr` there. Since v1.4.0 it calls the stdlib's arch-aware `sys_lstat`,
and the aarch64 build's output is byte-identical to x86_64's. aarch64 is still
not a declared supported target.)

**3. The directory-read ABI is a different call with a different record
layout.** The stdlib `dir_list` is Linux `getdents64` (#217) only. agnos uses
`getdents` (#29) with a packed `AgnosDirent`, parsed by `_d_dir_list_agnos`.

⛔ **Do not "simplify" that onto agnos `sys_readdir` (#81)**, added to the
stdlib in cycc 6.4.44. It looks like a drop-in replacement and is not: its
records are a fixed 64 bytes with the name at +0 and the type at +63, which
**caps filenames at 63 bytes**. Adopting it would silently truncate or drop
longer names.

**4. There is no ambient working directory.** agnos's userland ABI is
"CWD is userland-owned, absolute paths", so there is no `getcwd`. This is why
`--git` on agnos works only when given an absolute path: `_git_make_absolute`
returns a relative path unchanged, the repo-root walk-up finds no anchor, and
the column silently does not appear — the same degradation as the
out-of-a-repo case.

**Terminal detection is console-wide, not per-fd.** There is no
`ioctl`/`TIOCGWINSZ`; agnos reports the console grid through `winsize#60`,
which darshana's `tty_winsize` / `tty_isatty` read. It describes the
framebuffer, not fd 1, so it answers the same for a pipe or a file. Hence two
deliberate, opposite defaults (v1.4.0): `term_width` returns 0 on agnos, so
decoration and multi-column layout never reach a redirected listing; and name
sanitization keys on `tty_isatty`, so it is on whenever the console is up,
redirected or not. Each fails safe in its own direction.

**Consequence for error handling**: agnos reports a flat `-1` rather than a
specific errno, so the fine-grained `ENOENT` / `EACCES` branches simply fall
through to the generic message there. Code that switches on a specific errno
must degrade sensibly when it gets `-1` instead.

**Testing**: the agnos build runs under `mirshi --root <dir> <binary>`. There
is no substitute for actually running it — the Linux build passing proves
nothing about these paths.

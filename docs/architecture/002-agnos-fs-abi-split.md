# 002 — the agnos filesystem ABI differs from Linux in four ways, and `walk.cyr` hides all of them

**Applies to**: `src/walk.cyr`, `src/columns.cyr`, `src/git.cyr`.
**Landed**: v1.3.0.

darshini builds for Linux x86_64 and for AGNOS from the same source. The
divergence is *not* a matter of different syscall numbers for the same calls —
the two ABIs disagree about the shape of the operations themselves. Everything
below is `#ifdef CYRIUS_TARGET_AGNOS`-gated so the Linux path stays
byte-identical.

**1. `stat` and `open` take an explicit path length on agnos.** Linux takes a
NUL-terminated cstr. The wrappers `d_stat` / `d_open_ro` / `d_lstat` in
`walk.cyr` exist solely to hide this; call them rather than the raw syscalls.

**2. There is no `lstat` on agnos** — syscall 6 is `close` there, not `lstat`.
`d_lstat` falls back to `d_stat`, so on agnos a symlink reports its target.
(The same literal 6 is why the `--aarch64` build renders `?` for every
stat-derived column: on aarch64, 6 is not `lstat` either, and nothing there is
gated. aarch64 is not a supported target.)

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
out-of-a-repo case. There is also no `ioctl`/`TIOCGWINSZ`, so `term_width`
returns 0, which the pipe path already treats as "no terminal".

**Consequence for error handling**: agnos reports a flat `-1` rather than a
specific errno, so the fine-grained `ENOENT` / `EACCES` branches simply fall
through to the generic message there. Code that switches on a specific errno
must degrade sensibly when it gets `-1` instead.

**Testing**: the agnos build runs under `mirshi --root <dir> <binary>`. There
is no substitute for actually running it — the Linux build passing proves
nothing about these paths.

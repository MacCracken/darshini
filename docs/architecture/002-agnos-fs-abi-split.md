# 002 — the agnos filesystem ABI differs from Linux in four ways, and `walk.cyr` hides all of them

**Applies to**: `src/walk.cyr`, `src/columns.cyr`, `src/git.cyr`, `src/color.cyr`.
**Landed**: v1.3.0.

darshini builds for Linux x86_64 and for AGNOS from the same source. The
divergence is *not* a matter of different syscall numbers for the same calls —
the two ABIs disagree about the shape of the operations themselves. Everything
below is `#ifdef CYRIUS_TARGET_AGNOS`-gated so the Linux path stays
byte-identical.

**1. `stat` and `open` take an explicit path length on agnos.** Linux takes a
NUL-terminated cstr. The wrappers `d_stat` / `d_lstat` / `d_open_probe` /
`d_open_data` / `d_open_dir` in `walk.cyr` exist solely to hide this; call
them rather than the raw syscalls. (The open wrappers also carry the v1.4.1
non-blocking flags on Linux; agnos has no such flags, and its `fstat` is a
stub, so `d_fd_regular_size` answers "regular, size unknown" there.)

**2. `lstat` is newer on agnos than the target** — syscall 6 is `close` there,
not `lstat`, and through v1.7.0 `d_lstat` was `stat#33`, which follows, so on
agnos a symlink reported its target. agnos grew `lstat#102` at 1.56.53 (the
stdlib's `sys_lstat(path, len, buf)`), and since v1.8.0 `d_lstat` uses it when
the kernel has it. Which call is decided once, on the first path that can
decide it: `#33` and `#102` succeed on exactly the same backends (ext2, ZFS,
the `/fonts` intercept — both return -1 on FAT / exFAT), so lstat failing
where stat succeeds means no `#102` (mirshi 1.11.3, older kernels), and those
keep `#33`. A fixed probe path such as `/` would not do: it need not be on a
backend either call serves. The 1.7.0 stat-error rule (`emit_stat_error`)
follows the same answer — on with `#102`, off on the fallback, where a broken
link cannot be stat'd. Link targets stay off on agnos for another reason
(*The console size is console-wide*, below). mirshi has no `#102`, so CI
exercises only the fallback;
`tests/agnos-live.sh` boots a real kernel for the lstat path.
(Through v1.3.4 the Linux arm issued the literal 6 too, which is why the
`--aarch64` build rendered `?` for every stat-derived column — 6 is
`lsetxattr` there. Since v1.4.0 it calls the stdlib's arch-aware `sys_lstat`,
and the aarch64 build's output is byte-identical to x86_64's. aarch64 Linux is
a declared target since v1.8.0.)

**3. The directory-read ABI is a different call with a different record
layout.** Linux is `getdents64` (#217); agnos is `getdents` (#29) with a
packed `AgnosDirent`. From v1.3.0 to v1.4.0 darshini parsed the agnos form
itself (`_d_dir_list_agnos`), because the stdlib `dir_list` was Linux-only.
The stdlib has since grown the agnos arm, and `dir_list_checked` (cyrius
6.6.10) reports read errors instead of folding them into "empty" — so
v1.4.1 retired darshini's copy and calls the stdlib on every target.

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
out-of-a-repo case. (agnos's stat also has no owner field, so the
v1.5.0 `safe.directory` ownership check is compiled out there.)

**The console size is console-wide, not per-fd.** There is no
`ioctl`/`TIOCGWINSZ`; agnos reports the console grid through `winsize#60`,
which darshana's `tty_winsize` reads. It describes the framebuffer, not fd 1,
so it answers the same for a pipe or a file. Hence two deliberate, opposite
defaults (v1.4.0): `term_width` returns 0 on agnos, so decoration and
multi-column layout never reach a redirected listing; and name sanitization
keys on `tty_isatty`. Each fails safe in its own direction. Through darshana
1.4.0 `tty_isatty` also read the console, so sanitization was on whenever the
console was up, redirected or not. From darshana 1.5.0 (darshini 1.6.1) it
asks agnos 1.57.13's `fd_kind#111` about the fd itself (the console or a
terminal emulator's #97 channel), so a redirected listing is written raw, as
on Linux; on older kernels, and under mirshi, it keeps the console answer.
Through v1.8.0 `term_width` returned 0 on every kernel and `-l` showed no link
targets on agnos (v1.7.0 gates them on the same `tty_isatty`). Since v1.8.1
both are on where darshana 1.6.0's `tty_isatty_is_per_fd()` is 1 (agnos >=
1.57.13) and `tty_isatty(1)` is 1: color, icons, the grid and link targets on
the console or a terminal emulator's channel, as on Linux, and still nothing in
a redirected listing. On older kernels and under mirshi the probe is 0, so
there it is all still off. The grid takes `tty_winsize`'s width, which is the
console's even in an emulator window (darshana ADR 0008), so in a window
narrower than the console its rows wrap — chosen over one column on agnos
(2026-10-28). Sanitization keeps keying on `tty_isatty` alone: on an older
kernel that sanitizes a redirected listing too, the safe direction.

**Consequence for error handling**: agnos reports a flat `-1` rather than a
specific errno, so the fine-grained `ENOENT` / `EACCES` branches simply fall
through to the generic message there. Code that switches on a specific errno
must degrade sensibly when it gets `-1` instead.

**Testing**: the agnos build runs under `mirshi --root <dir> <binary>`. There
is no substitute for actually running it — the Linux build passing proves
nothing about these paths.

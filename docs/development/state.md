# darshini — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). History lives in the
> [CHANGELOG](../../CHANGELOG.md); the forward plan in
> [`roadmap.md`](roadmap.md).

## Version

**1.6.1** — toolchain and dependency patch, 2026-10-28: cyrius 6.7.9 →
6.7.18, darshana 1.3.0 → 1.5.0. No flag, exit code or Linux output byte
changed (A/B 0 / 276 on x86_64 and aarch64; on agnos under mirshi the
only difference is mirshi's own `ENOSYS agnos#110` stderr line). On
agnos ≥ 1.57.13 name sanitization now follows the fd (darshana 1.5.0's
per-fd `tty_isatty`). CI moved to `ubuntu-26.04` and SHA-pinned
actions; its first run there showed two gates assumed GNU coreutils
(26.04 ships uutils), both fixed in the gates, not in darshini.

Prior: **1.6.0** — display correctness, shipped 2026-10-15. Minor bump:
a new flag and visible output changes, every one a fix or an opt-in.

- **Columns measured in terminal cells**: UTF-8 decoded against a
  generated Unicode 16 width table (`src/width_table.cyr`, from
  `tests/gen-width-table.py`); CJK / emoji 2, combining marks 0.
- **Path arguments are one listing**: color, icons, `--git`, `-F`, the
  grid, one aligned `-l` table (`darshini *`, `-l a b c`, `-d */`).
- **`--mime` under `-T -l`** (was silently ignored).
- **`--local-time`** (opt-in; UTC stays default): TZif files and POSIX
  TZ strings with glibc's semantics, verified against `date(1)` for 33
  zones and TZ forms (`tests/tz-parity.sh`).
- **Pre-1970 mtimes render as dates** (Hinnant's civil algorithm; was
  the `????` placeholder since v1.3.2).

Earlier: **1.5.0** — `--git` reimplements git's rules
([ADR 0005](../adr/0005-git-status-semantics.md)). **1.4.x** — audit
and repair sweep, stdlib sort, CI cross-target runs. Earlier releases:
see the CHANGELOG.

## Toolchain

- **Cyrius pin**: `6.7.18` (in `cyrius.cyml [package].cyrius`)
- `lib/` is generated: `rm -rf lib/ && cyrius deps` (33 files at
  6.7.18 — the declared `[deps].stdlib` footprint, closed).
- Moving a dep tag: `cyrius deps` keeps the old commit row in
  `cyrius.lock` (fail-closed); delete `cyrius.lock` and run `cyrius
  deps` again to re-pin, then `cyrius deps --locked` to check.

## Shape

Binary (`darshini`). Single-shot CLI: walk a directory, render entries
to stdout, exit. Pipe-aware (plain output on non-TTY).

## Source

- `src/main.cyr` — entry point, argv parser (`parse_cli`), per-path
  dispatch (`run` / `run_all`), the path-argument listing
  (`render_args`), help / usage text
- `src/cli.cyr` — pure argv helpers (`_arg_eq`, `_parse_pos_int`,
  `_long_flag_code`); split out at v1.4.1 so the suite can include them
- `src/walk.cyr` — the buffered checked writer (`d_write` / `d_flush` /
  `_d_write_raw`), the stat / open wrappers (`d_stat`, `d_lstat`,
  `d_open_probe` / `_data` / `_dir`, `d_fd_regular_size`),
  `classify_path`, `check_dir_readable`, `list_dir_checked` (stdlib
  `dir_list_checked`, all targets), `d_basename`, `ModeBit` enum
- `src/render.cyr` — `_str_cmp_ci` / `str_lt_ci` (case-insensitive,
  raw-byte tiebreak: a strict total order), `sort_entries` (stdlib
  `vec_sort_by`), `print_entries`, `format_perms` / `_size_*` /
  `format_mtime` (Hinnant civil dates; UTC or `--local-time`)
- `src/width.cyr` / `src/width_table.cyr` — terminal cell width of
  UTF-8 (v1.6.0; the table is generated)
- `src/tz.cyr` — civil-date arithmetic and `--local-time`: TZif reader,
  POSIX TZ rules, glibc's posixrules fallback (v1.6.0)
- `src/long.cyr` — `-l` (two-pass: collect, then emit aligned), for a
  directory's entries and path arguments alike
- `src/columns.cyr` — `term_width` (darshana `tty_winsize`; 0 on agnos
  by decision), `pick_cols`, `render_columns`
- `src/color.cyr` — `color_for_mode`, `compute_decor` (one lstat pass
  for every decoration) and `compute_decor_args` (the same for path
  arguments), `emit_decorated`, the untrusted-text writers
  (`_write_name_bytes` / `_write_err_bytes` over darshana's
  `tty_sanitize_buf`), `emit_error` / `emit_dir_error`
- `src/icons.cyr` — compile-baked icon table mirroring
  `icons/default.cyml`
- `src/tree.cyr` — `-T`: depth-stack recursion, read-error reporting
- `src/ignore.cyr` — git's `wildmatch` (port) and gitignore pattern
  parsing / list matching; pure (v1.5.0)
- `src/gitcfg.cyr` — minimal git-config reader for the three keys
  `--git` needs (v1.5.0)
- `src/git.cyr` — repo discovery (physical path, `gitdir:` files,
  `commondir`), ownership (`safe.directory`), config, index v2/v3/v4
  (SHA-1 / SHA-256) parser with gitlink capture, ignore precedence and
  excluded-directory inheritance (memoized per directory), submodule
  `HEAD` status, status classifier, per-repo parse cache, prefix set
- `src/mime.cyr` — inode / filename / extension / exec / magic chain
  (ADR 0003), compile-baked table mirroring `mime/default.cyml`

## Features

| Feature | Since |
|---------|-------|
| Listing, `-l` / `-h`, multi-column / `-1`, color, icons, `-T` / `--level`, `--git`, `--mime` | M1–M8 (v0.2–v0.9) |
| v1.0 freeze | v1.0.0 |
| `--help` / `--version` / `-F` / `-d`; multi-path | v1.1.0 / v1.1.1 |
| AGNOS target | v1.3.0 |
| Checked writes (write error → exit 1) | v1.3.3 |
| Terminal sanitization of every untrusted name / path | v1.3.2, complete v1.4.0 |
| `--` end of options; `-F` on path arguments; read errors reported | v1.4.1 |
| `--git` with git's own rules: full ignore precedence, submodules, worktrees, `safe.directory` ([ADR 0005](../adr/0005-git-status-semantics.md)) | v1.5.0 |
| Columns in terminal cells; path arguments as one decorated listing; `-T -l --mime`; `--local-time`; pre-1970 dates | v1.6.0 |

Supported targets: **Linux x86_64, AGNOS**. The aarch64 build matches
x86_64 byte-for-byte (304 / 304 A/B captures; CI checks a 21-mode
matrix on every push since v1.4.2) but is not declared supported
(roadmap 1.8.0).

## Tests

- `tests/darshini.tcyr` — **527** assertions (v1.6.0; 463 at v1.5.0,
  301 at v1.4.0). v1.6.0: terminal cells (CJK, combining, emoji,
  malformed), the cells grid, path-argument decoration, civil dates and
  their round trip, POSIX TZ rules, TZif zones. Earlier: v1.5.0: git's 137-row wildmatch table (t3070),
  gitignore pattern semantics, precedence and inheritance, `.git`
  marks, git-config parsing, ownership / `safe.directory` matching.
  Pure helpers per module, the sanitizer rule, column math, the chrono
  layout pin, and since v1.4.1: the sort tiebreak and merge path,
  `classify_indicator`, the mtime bound, P / E sizes, `--level` bounds,
  `_long_flag_code`, `d_basename`, hand-built index images (v2, v3
  extended flags, v4 prefix compression, long names, SHA-256, misframing),
  `_git_oid_len`, every `--git` status outcome including the u32 compare
  and `git_status_for_root`, the hardened magic probe. Cross-targets,
  both run by CI since v1.4.2: aarch64 under `qemu-aarch64` 527 / 527;
  agnos under mirshi 508 / 508 (no ownership or TZif tests there; its
  errno assertions expect agnos's flat `-1`).
- `tests/darshini.fcyr` — 8 fuzz targets with named invariants
  (v1.5.0 added wildmatch vs an independent reference matcher, v1.6.0
  the civil-date round trip):
  `.git/index` (v2/v3/v4, SHA-1/SHA-256 framing), `.gitignore` (CRLF
  differential), magic bytes, `_path_join_into` (canary), the name
  sanitizer, the mtime formatter (v1.4.1, mutation-validated). Runs in
  CI since v1.4.1.
- `tests/darshini.bcyr` — micro-benchmarks (`cyrius bench`).
- `tests/tz-parity.sh` (v1.6.0: `--local-time` vs GNU `date(1)` across
  ~30 zones and TZ forms, random instants and every DST transition;
  fails without GNU date — v1.6.1 — and on Ubuntu 26.04 uses `gnudate`
  from gnu-coreutils),
  `tests/git-parity.sh` (v1.5.0: `--git` vs real git — ignore sets,
  `.git`, submodules, worktrees, ownership with sudo or as root; run it
  locally with the ownership part via
  `unshare --map-root-user --map-auto sh tests/git-parity.sh`),
  `tests/parity.sh` (two builds, 21 modes, pipe + PTY),
  `tests/table-drift.sh` (CYML vs compiled tables),
  `tests/examples.sh` (regenerates the golden `docs/examples/README.md`)
  — CI helpers, runnable locally from the repo root.
- CI (`.github/workflows/ci.yml`, every job on `ubuntu-26.04`, actions
  pinned by commit SHA since v1.6.1) — build, golden examples, strict
  lint, tests, fuzz, agnos (mirshi) + aarch64 (qemu) suite / fuzz runs
  and aarch64 output parity, git parity, tz parity, 25 smoke gates, DCE
  parity, security scan, table drift, docs / version consistency.

## Dependencies

- stdlib — string, fmt, alloc, io, vec, str, syscalls, args, fs,
  chrono, hashmap, assert, bench (`cyrius.cyml [deps].stdlib`).
- `[deps.darshana]` (git, tag **1.5.0**; needs cyrius ≥ 6.7.2 on
  Linux, ≥ 6.7.11 for an AGNOS build) — used:
  `tty_sgr_buf` / `tty_sgr_reset_buf` + `TTY_FG_*`, `tty_winsize`,
  `tty_isatty`, `tty_sanitize_buf` / `tty_has_ctl` +
  `TTY_SANITIZE_UTF8`. API frozen since 1.0.0 (additive only).
- CI test harness: [mirshi](https://github.com/MacCracken/mirshi)
  `1.11.3` (`MIRSHI_VERSION` in `ci.yml`; latest release). It has no
  `console_mode#110` / `fd_kind#111`, so darshana 1.5.0 takes its
  old-kernel path there and mirshi prints one `ENOSYS agnos#110` line
  to stderr per process.

## Consumers

_None._ darshini is end-user-facing; "consumers" are user shell
sessions and the maintainer's `ls` alias.

## Next

See [`roadmap.md`](roadmap.md): 1.7.0 (symlink targets on a terminal,
`NO_COLOR`, exit 1 for unstat-able entries, folder icon for directories,
icon / mime tables generated from CYML), then 1.8.0 (platforms).

## Known gotchas

- **`var buf[N]` is N bytes, not N slots** (the language guide is wrong
  here). Size every stack buffer against what the consumer can write.
  [`../architecture/001-var-buf-is-bytes.md`](../architecture/001-var-buf-is-bytes.md).
- **stdout is buffered** (v1.4.1). Everything bound for fd 1 must go
  through `d_write`; a bare `sys_write(1, …)` would land out of order.
  stderr writes flush stdout first, `main()` flushes before the exit
  check, and a harness that writes through `d_write` (the fuzz target)
  must call `d_flush()` before exiting.
- **Untrusted text has exactly two writers**: `_write_name_bytes`
  (stdout) and `_write_err_bytes` (stderr) in `color.cyr`. Anything
  darshini prints that it did not author goes through one of them.
  Metadata is untrusted too — `format_mtime` bounds the year for that
  reason.
- **mtime is UTC by default** (the v1.0 locale-free contract);
  `--local-time` opts into the user's zone. For POSIX TZ strings it
  follows glibc deliberately — including glibc's rule that such a
  string applies no DST before 1970 (northern rules), and its
  posixrules history for a DST name with no rule — so it agrees with
  GNU `date` and `ls -l`; past posixrules' last transition darshini uses
  the string's own offsets where glibc (a defect) uses the file's.
  uutils' `date` (Ubuntu 26.04's default `/usr/bin/date`) disagrees on
  exactly those strings — DST before 1970, a no-rule name read as UTC —
  so `tests/tz-parity.sh` insists on GNU's (`gnudate` there).
- **Grid widths are cells, from a generated table**: regenerate
  `src/width_table.cyr` with `tests/gen-width-table.py` (deliberately,
  not in CI — a runner's Python may carry another Unicode version).
- **AGNOS terminal detection depends on the kernel**: `term_width`
  returns 0 there (no decoration even on the console), while
  sanitization keys on `tty_isatty` — per fd on agnos ≥ 1.57.13
  (darshana 1.5.0, `fd_kind#111`), and on older kernels and under
  mirshi "is the console up", so a redirected listing is sanitized
  there. Opposite defaults, each failing safe. agnos also has no
  `getcwd` (`--git` needs an absolute path), a stub `fstat`, and no
  `lstat` wired yet
  ([`../architecture/002-agnos-fs-abi-split.md`](../architecture/002-agnos-fs-abi-split.md)).
- **CI runs on uutils coreutils** (ubuntu-26.04: `date`, `od`, `touch`,
  `stat`… are the Rust ports). In a `run:` block (bash, pipefail) never
  end a pipe from a coreutils producer with `grep -q` / `head`: uutils
  writes as it goes and dies of SIGPIPE, which fails a positive check
  and can silently pass a negative one — use `grep … > /dev/null`. An
  oracle that must be GNU says so by name (`tests/tz-parity.sh` →
  `gnudate`). Replay CI in an `ubuntu:26.04` container to see it.
- **`format_mtime` reads chrono's `DateTime` by named offset**
  (`DT_YEAR`…), pinned by assertions against the `dt_*` accessors.
  Migrating to the accessors was measured and rejected (each re-runs
  `epoch_to_date` with a fresh allocation).
- **Never swap the agnos directory read onto `sys_readdir` (#81)**: its
  64-byte records cap names at 63 bytes. The stdlib's `dir_list_checked`
  uses getdents (#29), which is what darshini wants.
- **Include order is convention, not a compiler requirement.** cycc
  resolves a call to a function defined later — in the same file or a
  later include (probed on 6.7.9 at v1.4.1, and on 6.7.18); older
  comments in the tree claimed otherwise. `main.cyr` keeps dependency
  order for readability.
  The compiler does reject an arity mismatch, so a signature change
  fails the build at every stale call site.
- **The stdlib has a `path_basename`** that keeps trailing slashes;
  darshini's is `d_basename`.
- **`--git` reads the environment** (v1.5.0): `HOME`,
  `XDG_CONFIG_HOME`, `GIT_CONFIG_NOSYSTEM`, `SUDO_UID` — as git does for
  the same settings. It does not honor `GIT_DIR` / `GIT_WORK_TREE`, and
  matching is case-sensitive (`core.ignoreCase` is not read). A test
  that must not see the user's own git config sets `HOME` /
  `XDG_CONFIG_HOME` to a temp dir and `GIT_CONFIG_NOSYSTEM=1`, as
  `tests/git-parity.sh` does.
- **Directory marks don't aggregate**: a directory whose untracked
  contents are all ignored, but which matches no pattern itself, shows
  `?` (git shows nothing for it). ADR 0005 §6.

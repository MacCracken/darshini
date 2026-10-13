# darshini — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**1.4.0** — cyrius 6.7.9 + darshana 1.3.0, darshini's terminal
code on darshana's primitives, and a sanitization fix, shipped
2026-10-12. Minor bump; no CLI flag, exit code or pipe byte
changes.

- **Security**: v1.3.2's sanitizer covered only the listing writer.
  Argv paths echoed as non-directories (`darshini *`) or by `-d`,
  the multi-path `<dir>:` header and paths in error messages
  (stderr) went to the terminal raw; raw C1 / malformed UTF-8
  passed even in a listing; and on AGNOS nothing was ever
  sanitized. All closed: names go through darshana's
  `tty_sanitize_buf` (UTF-8 mode), decided once per run per
  stream from `tty_isatty`.
- `term_width` is darshana's `tty_winsize`; escapes are composed
  with `tty_sgr_buf` / `tty_sgr_reset_buf` and written through the
  checked `d_write` (129 → 91 writes for a 30-entry `-1` on a TTY).
- AGNOS stays single-column / undecorated **by decision**: its
  `winsize#60` cannot tell fd 1 from the console, so it would
  decorate `darshini > file` (shown with a probe build under
  mirshi).
- Linux `lstat` is the stdlib `sys_lstat`; the aarch64 build's
  output is now byte-identical to x86_64's (52 modes, pipe + PTY).
- Toolchain migration: no source repair needed; `lib/` re-vendored
  (120 → 33 files).

287 → **301** assertions; fuzz target 5 is now the sanitizer,
mutation-validated; new CI gate for every name-to-terminal path.
Prior: **1.3.4** — toolchain `6.5.35` → `6.6.2`, no source change
(2026-09-11). Prior:
**1.3.3** — the v1.3.2 deferred backlog, shipped
2026-08-23. Closes every item the P(-1) sweep confirmed but
deferred, and one of the six turned out to be **wrong as
specified**:

- All 66 `sys_write` sites now route through a checked
  `d_write` (`walk.cyr`) that loops on short writes, retries
  `-EINTR`, and sets a sticky flag `main()` turns into exit 1.
  Through v1.3.2 `darshini > out.txt` on a full filesystem
  wrote nothing and exited **0**. Proven with `/dev/full`;
  new CI gate.
- `-l` stats each entry once instead of twice —
  `compute_decor` hands its stat buffers to `render_long`.
  **48.3 ms → 40.1 ms (~17%)** on 5,000 entries with
  `-l --mime`, zero output change.
- `tests/darshini.fcyr` is a real harness (5 targets, named
  invariants) instead of a no-op that made `cyrius fuzz`
  report PASS while running zero darshini code. Both the
  `.gitignore` and `_path_join_into` targets are
  **mutation-validated**: re-introducing the corresponding
  v1.3.2 bug makes them fail.
- `-T --git` root line `? .` → `. .` (new
  `git_status_for_root`). **The only behavior change in the
  release**; every line below the root is byte-identical.
- The agnos enumerator uses a stack scratch, ending a 4 KB
  permanent leak per directory visited.
- **Rejected**: migrating `format_mtime` to chrono's `dt_*`
  accessors. Each accessor re-runs `epoch_to_date` with a
  fresh `alloc(48)`, so using all five would cost 5
  conversions per entry on the `-l` hot path, and they take
  nanoseconds rather than the epoch seconds `stat` gives us.
  The offsets are instead **named** (`DT_YEAR`…`DT_SECOND`)
  and pinned by assertions that cross-check each against its
  accessor, so a reordered struct fails in the suite rather
  than silently rendering a wrong date.

272 → **287** assertions. Verified against a v1.3.2
reference across 45 A/B comparisons (TTY, pipe, agnos,
aarch64): zero differences outside the root-line change.
Patch bump. Prior:
**1.3.2** — P(-1) audit / refactor / hardening / security
sweep, shipped 2026-08-23. Six independent audit lenses over
`src/`, `tests/`, `docs/` and CI, every material finding put
through an adversarial refutation pass: **75 raised, 24
refutation-tested, 5 killed, 19 confirmed**. Full report in
[`../audit/2026-08-23-audit.md`](../audit/2026-08-23-audit.md).

v1.3.1 shipped **one memory-safety defect and one
terminal-injection vulnerability**, both reachable from
ordinary use, plus four wrong-answer bugs. All fixed:

- `_path_join_into` wrote past its fixed 4096-byte buffer
  with no capacity check — measured 76 bytes past the
  allocation, argv-reachable, silent because the bump
  allocator absorbed it. Present since v1.1.2. Found by
  four of the six lenses independently.
- Entry names reached the terminal raw, so a crafted
  filename executed control sequences — including
  cursor-up + erase-line to **hide a sibling file from the
  listing**. Now `?` per C0/DEL/UTF-8-C1 byte on a TTY
  (`ls -q` shape); raw on a pipe so scripts still get an
  openable name.
- `--git` reported every tracked file as untracked whenever
  the path was `.`, ended in `/`, or held a `/./` — i.e.
  bare `darshini --git` in any subdirectory, the commonest
  form of the flag.
- `-T --git` mislabelled everything below depth 1;
  `-T -l` printed *fabricated* perms/size/mtime for
  unstat-able entries; `format_mtime` emitted 0xD4 into the
  terminal for pre-1970 mtimes; a CRLF `.gitignore` matched
  nothing at all; an oversized `.git/index` was silently
  truncated; a dangling symlink as an argument aborted the
  whole run.

Every fix is byte-for-byte output-preserving on well-formed
input — the only output that changed is output that was
already wrong. Verified by 31 A/B comparisons against a
v1.3.1 reference binary (cycc 6.4.24) across TTY, pipe and
both cross-targets: zero differences. Suite **233 → 272**
assertions. Docs: `SECURITY.md` had claimed a sanitization
control that did not exist; `docs/adr/README.md` had said
"No ADRs yet" since v0.1.0 with four ADRs beside it;
`docs/architecture/` was empty and now carries three notes.
Patch bump. Prior:
**1.3.1** — cycc 6.5.35 + darshana 1.0.0, shipped
2026-08-23. Toolchain + dep bump, no darshini behavior
change on any target. The manifest pin had drifted a full
minor behind the installed wrapper (`6.4.24` vs `6.5.35`,
111 releases); this catches it up and `lib/` is re-synced
to the 6.5.35 snapshot (108 files). darshana `0.9.0` →
**`1.0.0`** is the upstream **API freeze**: the 29-fn /
37-const surface is now contract, and both symbols darshini
calls (`tty_sgr` / `tty_sgr_reset`) sit inside it — so
darshini's sole external dep is now a stable target. The
0.9.3 pre-freeze breaks (`tty_sgr_reset_buf` / `tty_dec_buf`
`-1` return; `AGNOS_*` → `_AGNOS_*`) touch zero darshini
call sites, and 0.9.3's `tty_sgr`-as-wrapper refactor is
byte-identical on the wire — verified here at the wire, not
taken from the upstream changelog. Verified byte-for-byte
against a v1.3.0 reference binary (cycc 6.4.24 + darshana
0.9.0) across **77 comparisons on four targets**: 26 modes
on a pipe, 27 under a real 80×24 PTY (the only runs that
actually emit SGR bytes), 12 on agnos under `mirshi --root`,
12 on the aarch64 build under `qemu-aarch64` — identical in
every one. The aarch64 row is a **no-regression** check, not
a support claim: that build still shows `?` for every
stat-derived column (the bare-syscall-6 `lstat_path` gotcha
below), byte-for-byte as before the bump. Supported targets
stay Linux x86_64 + agnos. 233/233 green, lint clean, fuzz
green. Patch bump. Prior:
**1.3.0** — agnos target support + cycc 6.4.24 +
darshana 0.9.0, shipped 2026-07-08. darshini now builds
`cyrius build --agnos` and **runs on AGNOS under mirshi** —
full listing across every mode (plain / `-l` / `-F` / `-T`
/ `--git` / `--mime`), all `#ifdef CYRIUS_TARGET_AGNOS`
-gated so the Linux/macOS paths stay byte-identical
(233/233 green). Ported the FS-ABI split behind the initial
`SYS_GETCWD` break: getcwd-gated `--git`; explicit-length
`stat`/`open` wrappers; a native `getdents`(#29)
`AgnosDirent` enumerator (the stdlib `dir_list` is
Linux-#217-only); `ioctl`/`TIOCGWINSZ` → 0 in `term_width`;
`ENOENT`/`EACCES` defined for agnos. Added `darshini` to
the agnosticos agnos-dev docker image (`DELTA[dev]`).
Toolchain: pin `6.2.22` → `6.4.24` (`lib/` re-synced, 98
files); darshana `0.7.1` → `0.9.0` (dep-bump-only —
`tty_sgr` / `tty_sgr_reset` unchanged across 0.7→0.9).
Minor bump: new platform, no CLI-contract or behavior
change on existing targets. Prior:
**1.2.1** — cycc 6.2.22 + darshana 0.7.1, shipped
2026-06-18. Toolchain bump: the installed wrapper had
moved to `6.2.22` while the manifest pin stayed `6.1.26`
(drift warning every build); this catches the manifest
up. darshana `0.7.0` → `0.7.1` is itself a toolchain-only
upstream cut (no source / API change, module bodies
byte-identical, regenerated only to stamp the 6.2.22
header), so darshini's color path is byte-identical and
no call-site repair was needed (verified: clean build +
233/233 green). Patch bump — no darshana surface move
this time. `lib/` refreshed to the 6.2.22 snapshot. Prior:
v1.2.0 darshana 0.7.0 (breaking upstream) + cycc
6.1.26, shipped 2026-06-10. darshana's pre-freeze
API-reshaping cut broke 4 symbols (`tty_cooked`,
`tty_itoa`, `tty_clear_to_end`, `tty_apply_raw_flags`),
**none of which darshini calls** — our surface is
`tty_sgr` / `tty_sgr_reset`, both unchanged, so no
call-site repair was needed (verified: clean build +
233/233 green on 0.7.0). cycc pin `6.1.24` → `6.1.26`,
`lib/` refreshed. CLI contract unchanged; minor bump
reflected the dep major-surface move. Prior: v1.1.4
darshana `0.5.4` → `0.6.0` (test-only); v1.1.3 toolchain
bump (cycc `6.0.0` → `6.1.24`, darshana `0.5.3` → `0.5.4`).
Earlier: v1.1.2 hot-path optimizations 2026-05-23 (hybrid
sort + pick_cols early-out + path_join buf reuse). Same day
as v1.1.0 (`--help` / `--version` / `-F` / `-d` + merge-sort
+ git hashmap) and v1.1.1 (multi-path argv). v1.0.0 froze
the contract earlier same day; M1–M9 shipped 2026-05-22/23.
Scaffolded as **0.1.0** on 2026-05-19 via `cyrius init
darshini`. Non-breaking under the M10 freeze.

## Toolchain

- **Cyrius pin**: `6.7.9` (in `cyrius.cyml [package].cyrius`)
- `lib/` is generated: `rm -rf lib/ && cyrius deps` (33 files at
  6.7.9 — the declared `[deps].stdlib` footprint, closed).

## Shape

Binary (`darshini`). Single-shot CLI: walk a directory, render entries
to stdout, exit. Pipe-aware (plain output on non-TTY).

## Source

- `src/main.cyr` — entry point + argv flag parser + dispatch
- `src/walk.cyr` — `d_write` (checked writer), `classify_path`,
  `check_dir_readable`, `list_dir`, `lstat_path` (stdlib `sys_lstat`
  on Linux), `ModeBit` enum (POSIX S_IF*/S_I* constants)
- `src/render.cyr` — `lower_byte`, `str_lt_ci`, `sort_entries`,
  `print_entries`, `format_perms`, `format_size_decimal`,
  `format_size_human`, `format_mtime`
- `src/long.cyr` — long-format orchestrator (two-pass:
  collect-stat-then-emit-aligned)
- `src/columns.cyr` — `term_width` (darshana `tty_winsize`; 0 on
  agnos by decision), `pick_cols` / `_pick_cols_w`,
  `_display_widths`, `render_columns` (vertical-then-horizontal)
- `src/color.cyr` — `color_for_mode` picker, `compute_decor`
  fs-side parallel-vec builder (colors + icons in one lstat
  pass), `emit_decorated` (darshana `tty_sgr_buf` /
  `tty_sgr_reset_buf`, three checked writes per entry), and the
  untrusted-text writers `_write_name_bytes` / `_write_err_bytes`
  / `_name_display_len` over darshana's `tty_sanitize_buf`
- `src/icons.cyr` — compile-baked icon picker (`icon_for_entry`,
  `icon_display_width`) mirroring `icons/default.cyml`
- `src/tree.cyr` — `render_tree` + the depth-stack recursion;
  `_tree_prefix_buf` / `_tree_connector_buf` for testable
  byte-sequence helpers
- `src/git.cyr` — `.git/index` v2 parser + minimal
  `.gitignore` parser + `git_status_for` classifier
  (`.`/`M`/`?`/`!`). Single GitCtx loaded per listing.
- `src/mime.cyr` — `mime_for_entry` master + the
  inode/filename/ext/exec/magic precedence chain
  per ADR 0003. Compile-baked mapping mirroring
  `mime/default.cyml`.

M9+ onward fills:

- M9: P(-1) hardening + audit doc + bench baseline (pre-v1.0)

## Features

| Feature | Milestone | Status |
|---------|-----------|--------|
| Basic listing | M1 | **shipped** (v0.2.0) |
| `-l` long format + `-h` human sizes | M2 | **shipped** (v0.3.0) |
| Multi-column auto-layout, `-1` | M3 | **shipped** (v0.4.0) |
| Color via darshana | M4 | **shipped** (v0.5.0) |
| Icons via CYML mapping | M5 | **shipped** (v0.6.0) |
| `-T` / `--tree` | M6 | **shipped** (v0.7.0) |
| `--git` status column | M7 | **shipped** (v0.8.0) |
| `--mime` recognition | M8 | **shipped** (v0.9.0) |
| Pre-v1 audit + bench baseline | M9 | **shipped** (v0.9.1) |
| v1.0.0 freeze | M10 | **shipped** (v1.0.0) |
| v1.1: `--help` / `--version` / `-F` / `-d` + merge-sort + git hashmap | v1.1 | **shipped** (v1.1.0) |
| v1.1.1: multi-path argv (full eza alias retirement) | v1.1.1 | **shipped** (v1.1.1) |
| v1.1.2: hybrid sort + pick_cols early-out + path_join buf reuse | v1.1.2 | **shipped** (v1.1.2) |
| v1.1.3: toolchain bump (cycc 6.1.24, darshana 0.5.4) | v1.1.3 | **shipped** (v1.1.3) |
| v1.1.4: darshana dep bump (0.6.0, test-only upstream) | v1.1.4 | **shipped** (v1.1.4) |
| v1.2.0: darshana 0.7.0 (breaking, no repair) + cycc 6.1.26 | v1.2.0 | **shipped** (v1.2.0) |
| v1.2.1: cycc 6.2.22 + darshana 0.7.1 (toolchain-only) | v1.2.1 | **shipped** (v1.2.1) |
| v1.3.0: agnos target support (FS-ABI port) + cycc 6.4.24 + darshana 0.9.0 | v1.3.0 | **shipped** (v1.3.0) |
| v1.3.1: cycc 6.5.35 + darshana 1.0.0 (upstream API freeze) | v1.3.1 | **shipped** (v1.3.1) |
| v1.3.2: P(-1) audit sweep — OOB write + terminal-injection + 6 wrong-answer fixes | v1.3.2 | **shipped** (v1.3.2) |
| v1.3.3: deferred backlog — checked writes, single-lstat `-l`, real fuzz harness | v1.3.3 | **shipped** (v1.3.3) |
| v1.3.4: cycc 6.6.2 (toolchain-only) | v1.3.4 | **shipped** (v1.3.4) |
| v1.4.0: cycc 6.7.9 + darshana 1.3.0; darshana primitives; sanitization on every path + AGNOS | v1.4.0 | **shipped** (v1.4.0) |

## Tests

- `tests/darshini.tcyr` — **301** assertions (v1.4.0) across M1
  (lower_byte, str_lt_ci, sort_entries, classify_path,
  check_dir_readable), M2 (format_perms, format_size_*,
  format_mtime + the chrono layout pin), M3 (pick_cols,
  _columns_total_width), M4 (color_for_mode), M5 (icons), M6
  (tree byte helpers, _parse_pos_int), M7 (git index / ignore /
  normalize / listing-rel), M8 (mime), and since v1.4.0 the
  sanitizer rule (`_sanitize_into`), `_name_display_len`, the
  widths-aware column math and the `term_width` ⇔ `tty_isatty`
  contract. Also builds for the cross-targets: aarch64 under
  `qemu-aarch64` 301 / 301; agnos under `mirshi` 299 / 301 — the
  two `-ENOENT` assertions fail by agnos's flat `-1` design, as on
  v1.3.4 (285 / 287). Not run in CI.
- `tests/darshini.bcyr` — benches: sort, pick_cols, path join,
  color / icon / mime picks (`cyrius bench`)
- `tests/darshini.fcyr` — 5 fuzz targets with named invariants:
  `.git/index`, `.gitignore` (CRLF differential), magic bytes,
  `_path_join_into` (canary), the name sanitizer (v1.4.0);
  mutation-validated
- CI (`.github/workflows/ci.yml`) — 17 smoke gates, DCE parity,
  security scan, docs / version consistency

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, args, fs,
  chrono, hashmap, assert, bench. `args` + `fs` added at M1 (argv
  access + getdents64-backed dir_list); `chrono` added at M2 for
  `epoch_to_date` + the 2-digit / 4-digit formatting helpers;
  `hashmap` added at v1.1.0 for the `--git` status map. (This list
  had omitted `hashmap` since v1.1.0 — corrected at v1.3.1; the
  manifest was always right.)
- `[deps.darshana]` (git, tag **1.3.0**; needs cyrius ≥ 6.7.2) —
  TTY/ANSI primitives. First external dep; landed at M4 for the
  color escapes. Used since v1.4.0: `tty_sgr_buf` /
  `tty_sgr_reset_buf` + `TTY_FG_*` (color), `tty_winsize` (width),
  `tty_isatty` (per-stream terminal test), `tty_sanitize_buf` /
  `tty_has_ctl` + `TTY_SANITIZE_UTF8` (untrusted names). darshana's
  API is frozen since 1.0.0 (additive only), so a break there costs
  upstream a major bump plus an ADR.

## Consumers

_None yet._ darshini is end-user-facing; "consumers" are user
shell sessions and the maintainer's `ls` alias.

## Next

The 1.x backlog lives in [`roadmap.md`](roadmap.md) "1.x backlog":
mtime localization; platforms (aarch64 output now matches x86_64 —
declaring it supported is an owner call — then macOS / BSD /
Windows); AGNOS decoration once agnos has a per-fd terminal test;
agnos `lstat#102`; byte-vs-cell column widths for multibyte names.

Two stdlib-enabled candidates carried from the v1.3.1 sweep,
neither a defect, both non-breaking:

- **`vec_sort_by` / `vec_select_nth`** (cycc 6.5.4) could
  replace `render.cyr`'s hand-rolled merge sort — cycc's
  changelog names darshini's sort as a motivating case, and the
  stdlib introsort is O(1) extra memory against the current
  per-call scratch vec the bump allocator never reclaims.
- **`CYRIUS_PKG_VERSION`** (cycc 6.5.21) would let
  `_darshini_version_str()` stop being a hand-bumped literal,
  retiring the lockstep step and the CI grep that guards it.

Both were left out of v1.4.0, which already carried a language
minor and a dep bump.

## Known gotchas

- **`var buf[N]` is N bytes, not N slots.** Cyrius 6.0.1 contradicts
  the language guide here. `classify_path` sizes its stat buffer
  as `var buf[144]` (= `STAT_BUFSZ`). Misreading the guide and
  writing `var buf[18]` silently corrupts adjacent rodata
  (caught at M1 when `"\n"` literal in the same TU started
  emitting 0xed). Audit any new stat / read syscall buffer
  sizing against actual byte width.
- **mtime is UTC, not local time** under `-l`. The v1.0 contract
  picks locale-free + stable over matching `ls -l`'s local-time
  default; users comparing the two side-by-side will see their
  UTC-offset as a discrepancy. Documented in the M2 CHANGELOG.
- **Supported targets are Linux x86_64 and agnos** (agnos since
  v1.3.0). The aarch64 build is **not** declared supported, but
  since v1.4.0 its output is byte-identical to x86_64's across the
  52-mode A/B matrix (pipe and PTY, under `qemu-aarch64`). Through
  v1.3.4 every stat-derived column rendered `?` there: `lstat_path`
  issued x86_64's syscall 6 bare, which is `lsetxattr` on aarch64.
  v1.4.0 calls the stdlib's arch-aware `sys_lstat`. The other two
  x86-isms the v1.3.1 note listed are gone too: the window-size
  ioctl is darshana's `tty_winsize` (darshana covers Linux + AGNOS
  only — a macOS / BSD port needs a darshana arm or its own), and
  `st_mode` is read through the stdlib's per-target `STAT_MODE`.
- **AGNOS terminal detection is console-wide.** darshana's
  `tty_winsize` / `tty_isatty` on agnos read `winsize#60`, a
  framebuffer property: they answer the same whether fd 1 is the
  console, a pipe or a file. So `term_width` returns 0 on agnos
  (no decoration, single column — otherwise `darshini > file`
  gets escapes and icons), while name sanitization keys on
  `tty_isatty` and is on whenever the console is up, even in a
  redirected listing. Opposite defaults, each failing safe. See
  `docs/architecture/002-agnos-fs-abi-split.md`.
- **Terminal output of untrusted text has exactly two writers**:
  `_write_name_bytes` (stdout) and `_write_err_bytes` (stderr) in
  `color.cyr`. Anything darshini prints that it did not author —
  a name, an argv path, a path in a diagnostic — must use one of
  them; the CI gate *untrusted names are neutralized on a TTY*
  exercises every current call path.

- **`format_mtime` reads chrono's `DateTime` by raw byte offset**
  — deliberate as of v1.3.3, and now *pinned* rather than
  merely noted. The offsets are named `DT_YEAR`…`DT_SECOND`
  in `render.cyr`, and a `chrono DateTime layout pin` group
  in the suite cross-checks each against its `dt_*` accessor
  and against known values, so an upstream reorder fails
  there instead of silently rendering a wrong date. Migrating
  to the accessors was measured and rejected: each re-runs
  `epoch_to_date` with a fresh `alloc(48)`, so all five would
  cost 5 conversions per entry on the `-l` hot path, and they
  take nanoseconds rather than epoch seconds. Original note:
  `render.cyr:321-330` does `load64(d)`, `load64(d + 8)` … `load64(d
  + 32)` for year/month/day/hour/minute on the struct `epoch_to_date`
  returns. cycc 6.4.67 added public accessors (`dt_year` / `dt_month`
  / `dt_day` / `dt_hour` / `dt_minute` / `dt_second`) whose stated
  purpose is to *keep that layout private* — so darshini now depends
  on an explicitly-unsupported detail. Verified safe at v1.3.1: the
  `lib/chrono.cyr` delta is purely additive (+307/-0) and
  `epoch_to_date`'s body is unchanged, so `-l` mtimes are
  byte-identical. Move to the accessors before the layout moves under
  us.

- ~~**darshini's agnos `dir_list` mirror bump-allocates its
  getdents scratch.**~~ **Fixed in v1.3.3** — now a stack
  local, ending a 4 KB permanent leak per directory visited.
  Kept here because the *reason* still matters for any new
  scratch buffer: original note follows. cycc 6.5.11 moved the stdlib `dir_list` /
  `is_dir` 4 KB scratch from `alloc()` to a stack local, because the
  default allocator is a *bump* allocator with no free — the upstream
  note measures the old cost at 4104 B **per call**. darshini's Linux
  path uses the stdlib and so picked the fix up for free at v1.3.1;
  its agnos peer `_d_dir_list_agnos` (`walk.cyr:154`) still reads
  `var buf = alloc(4096)`. So the bump *introduced an asymmetry*: on
  agnos, every directory visited still burns 4 KB that is never
  returned, which compounds under `-T` on a deep tree. One-line fix
  (`var sbuf[4096]; var buf = &sbuf;`), deliberately **not** taken in
  the v1.3.1 patch cut — it is an agnos behavior change and wants its
  own test pass.

- **Do not "simplify" `_d_dir_list_agnos` onto agnos `sys_readdir`.**
  cycc 6.4.44 added a `sys_readdir` (#81) wrapper that looks like it
  obsoletes darshini's hand-rolled `sys_getdents` (#29) enumerator.
  It does not: its records are a fixed 64 bytes with the name at +0
  and the type at +63, which **caps filenames at 63 bytes**. Adopting
  it would silently truncate or drop longer names. The #29 constants
  darshini depends on (`DIRENT_RECLEN` / `_TYPE` / `_NAMELEN` /
  `_NAME`, `AO_DIRECTORY`) are unchanged across this bump. Keep #29.

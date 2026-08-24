# darshini — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

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

- **Cyrius pin**: `6.5.35` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`darshini`). Single-shot CLI: walk a directory, render entries
to stdout, exit. Pipe-aware (plain output on non-TTY).

## Source

- `src/main.cyr` — entry point + argv flag parser + dispatch
- `src/walk.cyr` — `classify_path`, `check_dir_readable`, `list_dir`,
  `lstat_path`, `ModeBit` enum (POSIX S_IF*/S_I* constants)
- `src/render.cyr` — `lower_byte`, `str_lt_ci`, `sort_entries`,
  `print_entries`, `format_perms`, `format_size_decimal`,
  `format_size_human`, `format_mtime`
- `src/long.cyr` — long-format orchestrator (two-pass:
  collect-stat-then-emit-aligned)
- `src/columns.cyr` — `term_width` (ioctl TIOCGWINSZ),
  `pick_cols`, `render_columns` (vertical-then-horizontal)
- `src/color.cyr` — `color_for_mode` picker, `compute_decor`
  fs-side parallel-vec builder (colors + icons in one lstat
  pass), `emit_decorated` write wrap
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

## Tests

- `tests/darshini.tcyr` — 233 assertions across M1 (lower_byte,
  str_lt_ci, sort_entries, classify_path, check_dir_readable),
  M2 (format_perms, format_size_decimal, format_size_human,
  format_mtime), M3 (pick_cols, _columns_total_width), M4
  (color_for_mode), M5 (icon_display_width, icon_for_entry,
  pick_cols + icon_width), M6 (_tree_connector_buf,
  _tree_prefix_buf, _parse_pos_int), and M7 (_be_u32 / _be_u16,
  _git_parse_index header, _git_match_one, _git_listing_rel)
- `tests/darshini.bcyr` — benchmark stub
- `tests/darshini.fcyr` — fuzz stub

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, args, fs,
  chrono, hashmap, assert, bench. `args` + `fs` added at M1 (argv
  access + getdents64-backed dir_list); `chrono` added at M2 for
  `epoch_to_date` + the 2-digit / 4-digit formatting helpers;
  `hashmap` added at v1.1.0 for the `--git` status map. (This list
  had omitted `hashmap` since v1.1.0 — corrected at v1.3.1; the
  manifest was always right.)
- `[deps.darshana]` (git, tag 1.0.0) — TTY/ANSI/cursor primitives.
  First external dep; landed at M4 for the color escapes. All
  raw ANSI routes through darshana's `tty_sgr` / `tty_sgr_reset`
  per CLAUDE.md. **Frozen upstream as of 1.0.0** — both symbols
  darshini calls are inside the 29-fn / 37-const contract, so a
  future break there costs upstream a major bump plus an ADR.

## Consumers

_None yet._ darshini is end-user-facing; "consumers" are user
shell sessions and the maintainer's `ls` alias.

## Next

v1.2 backlog (per user direction post-v1.1.1):

- **mtime localization** — keep UTC default; add an opt-in
  flag for local time per the M2 notes.
- **Platform support** — aarch64 Linux first, then macOS /
  BSD / Windows. Arch-specific sites enumerated below in
  "Known gotchas".

Hot-path optimization candidates from
[`docs/benchmarks.md`](../benchmarks.md) all shipped in
v1.1.2. Two new candidates were surfaced by the v1.3.1
toolchain sweep — both are additions the 6.5.35 stdlib made
available, neither is a defect:

- **`vec_sort_by` / `vec_select_nth`** (cycc 6.5.4) could
  replace `render.cyr`'s hand-rolled merge sort. cycc's own
  changelog names darshini's sort as one of the two motivating
  cases. `sort_entries` allocates an N-slot scratch vec per
  call that the bump allocator never reclaims; the stdlib
  introsort is O(1) extra memory.
- **`CYRIUS_PKG_VERSION`** (cycc 6.5.21) now resolves from
  included files, which would let `_darshini_version_str()`
  stop being a hand-bumped literal and read `VERSION`
  directly — retiring the lockstep-bump step in CLAUDE.md's
  Work Loop and the CI grep that guards it.

Both are non-breaking additions permitted under the M10
freeze, and both were left out of the v1.3.1 patch cut as
source changes beyond a dep bump.

**Deferred out of the v1.3.2 P(-1) cut** (confirmed
findings, accepted with rationale in the audit's "Deferred"
table — none are regressions, all tracked for 1.4.0):

- **`sys_write` returns are never checked** — 56 sites. A
  full filesystem yields exit 0 with truncated output; a
  closed stdout the same. Wants a looping `d_write` wrapper
  plus a sticky failure flag threaded to `main()` — every
  output path, which does not belong in a patch cut
  alongside seven other repairs.
- **`-l` stats every entry twice** — `compute_decor` and
  `render_long` each `lstat` the whole listing: 2 syscalls
  per entry where 1 suffices. Pure perf, no wrong output.
  Needs `compute_decor` to widen its returned struct and
  hand its stat buffers back.
- **`tests/darshini.fcyr` is a stub** — `cyrius fuzz`
  passes while executing zero darshini code, so every
  attacker-facing byte path (index parser, gitignore
  matcher, magic bytes, filenames) is unfuzzed. A 512-line
  replacement was drafted during the sweep; adopting it
  wants its own review pass.
- **`-T --git <dir>` root line** shows `?` for the tree root
  itself — the root's rel should be the listing prefix
  rather than prefix + name. Pre-existing, unchanged by the
  v1.3.2 tree fix, cosmetic.
- The agnos scratch-alloc asymmetry and the chrono
  `DateTime` raw-offset dependency, both already described
  under "Known gotchas" below.

Non-roadmap items remain non-breaking additions per the M10
freeze contract.

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
  v1.3.0). `cyrius build --aarch64` *compiles and runs*, but the
  binary is not usable: measured at v1.3.1 under `qemu-aarch64`,
  every stat-derived column renders as `?` placeholders —
  `?????????? ? ????-??-?? ??:??` under `-l`, no `/` or `@`
  classification under `-F`, no recursion under `-T`, and
  misclassified `--git` status. Plain listing, `-1`, `-d` and
  `--mime` (which does not need stat for the filename/ext arms)
  are correct. It degrades rather than crashing, and is
  byte-for-byte identical pre- and post-v1.3.1, so the toolchain
  bump neither fixed nor worsened it. Per roadmap "Out of scope",
  non-x86 Linux is **post-v1**. The three x86_64 dependencies to
  fix when platform work opens: (a) `walk.cyr`'s `lstat_path`
  uses bare syscall 6 — on aarch64 that is not `lstat`, and this
  is the cause of the `?` columns above; aarch64 needs an
  at-family detour through `newfstatat`; (b) `columns.cyr`'s
  `TIOCGWINSZ_LINUX = 0x5413` is Linux-only (BSDs use a
  different request number); (c) `walk.cyr` reads `st_mode` at
  offset 24 per the x86_64 stat layout. All three already use
  the `Stat` enum or local constants, so the arch-dispatch
  pattern is clear when the time comes.

- **`format_mtime` reads chrono's `DateTime` by raw byte offset.**
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

- **darshini's agnos `dir_list` mirror still bump-allocates its
  getdents scratch.** cycc 6.5.11 moved the stdlib `dir_list` /
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

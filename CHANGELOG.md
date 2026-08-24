# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.3.2] — v1.3.2: P(-1) audit / hardening / security sweep

A full P(-1) sweep — six independent audit lenses over `src/`, `tests/`,
`docs/` and CI, every material finding put through an adversarial refutation
pass. **75 raised, 24 refutation-tested, 5 killed, 19 confirmed.** Full report:
[`docs/audit/2026-08-23-audit.md`](docs/audit/2026-08-23-audit.md).

v1.3.1 shipped one memory-safety defect and one terminal-injection
vulnerability, both reachable from ordinary use, plus four wrong-answer bugs in
`--git` and `-T`. All are fixed here.

**Every fix is byte-for-byte output-preserving on well-formed input** — the
only output that changes is output that was already wrong. Verified by 31 A/B
comparisons against a v1.3.1 reference binary (built with cycc 6.4.24) across
TTY, pipe, and both cross-targets: zero differences. Suite 233 → **272**
assertions, lint clean, `vet` 9/0/0, DCE parity byte-identical, agnos re-run
under `mirshi`.

### Security

- **Terminal escape injection via filenames.** Entry names went to the terminal
  byte-for-byte, so a crafted filename executed terminal control sequences.
  Demonstrated: a name clears the screen, sets the window title, overwrites its
  own line, resets the SGR state darshini set — and, using cursor-up plus
  erase-line, **erases the preceding entry**, letting a hostile archive hide a
  sibling file from the listing. `ls`, `eza` and BSD `ls` all sanitize here.

  On a TTY, `?` now replaces each C0 byte (0x00–0x1f), DEL, and the UTF-8
  encoding of the C1 controls (0xC2 0x80–0x9F) — the shape `ls -q` uses. One
  `?` **per byte**: every width calculation measures `str_len(name)`, so a
  length-preserving substitution keeps that arithmetic correct untouched, and
  incidentally fixes the alignment of such rows. Bytes ≥ 0x80 are left alone,
  so UTF-8 names render intact — which depends on `load8` being unsigned,
  established by probe and now guarded by seven assertions that fail if it
  changes.

  **On a pipe the true bytes are still written**, matching
  `ls --quoting-style=literal`, so `darshini | while read -r f` yields an
  openable name. Gated on `term_width() > 0`, deliberately not on `want_color`:
  `--no-color` disables decoration, not the terminal.
- **Heap out-of-bounds write in `_path_join_into`** (`src/color.cyr`). It
  `memcpy`'d `dir + '/' + name + NUL` into a fixed 4096-byte buffer with no
  capacity check at all; a listing path near `PATH_MAX` holding a `NAME_MAX`
  entry needs 4353 bytes. Measured **76 bytes past the end** of the allocation
  on a 3915-byte directory holding a 255-byte name — reachable from `argv`, and
  silent, because the bump allocator's slack absorbs it. Present since v1.1.2.
  Now bounded before the first write; an overlong join renders the same `?`
  row it always did, because the syscall would fail `ENAMETOOLONG` anyway.
  Found independently by four of the six lenses.

### Fixed

- **`--git` reported every tracked file as untracked** whenever the listing path
  was `.`, had a trailing `/`, or contained a `/./` — which includes bare
  `darshini --git` inside any repository subdirectory, the most common form of
  the flag. The un-normalized path defeated the repo-root walk-up, so entries
  were looked up as `src/./a.txt` against an index keyed on `src/a.txt`. It
  worked at the repo root only by accident. `_git_normalize_abs` now collapses
  `//`, drops `.` components and strips trailing `/`; verified across 11
  invocation forms against `git ls-files`.

  `..` is deliberately **not** resolved lexically — the walk-up probes with
  `stat(2)`, so the kernel resolves it symlink-aware. Resolving it here would
  bind `/a/link/..` to the wrong repository, breaking a case that works today.
- **`-T --git` mislabelled every tracked file below depth 1.** The git context's
  prefix is fixed at the tree root, but the recursion passed bare basenames, so
  `src/deep/c.txt` was looked up as `c.txt`. A `rel_prefix` is now threaded
  through the recursion. Depth 1 is byte-identical; ignore-pattern matching
  still uses the basename, so those semantics are unchanged.
- **`-T -l` printed fabricated permissions, size and mtime** for entries whose
  `lstat` failed — the long-format prefix was emitted *before* the caller's
  `rc >= 0` guard, so it read a never-written buffer and rendered a confident
  `---------- 0 1970-01-01 00:00`. Reproduced on a readable-but-not-searchable
  directory, where flat `-l` correctly showed `?` placeholders for the same
  entries. It now matches flat `-l`, sharing its mtime placeholder rather than
  duplicating the byte pattern.
- **`format_mtime` emitted non-ASCII bytes for pre-1970 timestamps.** Negative
  epochs drive `epoch_to_date` negative and `_chrono_w2` writes `48 + n` for a
  negative `n`; a 1960 mtime rendered as `1970-01-\xD4+ /.:00`, putting 0xD4
  into the terminal and contracting the fixed 16-byte field. Reachable from
  restored backups and extracted tarballs. Now degrades to the standard
  placeholder at exact width; epochs ≥ 0 are byte-identical.
- **A CRLF-authored `.gitignore` matched nothing** — no ignore rule fired at
  all. The trailing CR was trimmed and then silently re-admitted by a restore
  that used the line end (still pointing at the `\n`), so `build/\r` was not a
  directory pattern and `*.swp\r` matched nothing. Verified against
  `git status --ignored`; LF inputs byte-identical.
- **An oversized `.git/index` was silently truncated**, reporting every entry
  past the 4 MB cutoff as untracked. `_git_slurp` also assumed a single
  `sys_read` fills its buffer. It now sizes from `stat(2)` and reads to EOF,
  with the cap as a sanity ceiling (256 MB): a file beyond it yields no git
  context — the column silently doesn't appear — rather than appearing and
  lying. Side benefit: a FIFO stats at size 0 and is refused, so `--git` no
  longer blocks forever on a planted `.git/index` FIFO. (Real `git` does hang
  on that, so this is an improvement over the reference, not a parity fix.)
- **A dangling symlink named as an argument aborted the run.** `classify_path`
  used the follow-stat, so `darshini broken` exited 1 with "no such file or
  directory" — while the same link listed as a *member* of its directory
  rendered fine, and `ls -l broken` exits 0. In a multi-path invocation one
  dangling link forced a non-zero exit for every other path. Now retries with
  `lstat`; symlink-to-directory arguments still follow to their target, and a
  genuinely missing path still exits 1.

### Changed

- **`SECURITY.md` documented a control that did not exist** — it claimed
  darshini sanitized control characters in entry names, and that it refused to
  parse oversized `.git/` files. Neither was true. Both are true as of this
  release, and the section now states exactly what happens, including the
  deliberate TTY/pipe asymmetry.
- **`docs/adr/README.md`** read "_No ADRs yet_" from v0.1.0 through v1.3.1 while
  all four ADRs sat beside it. Now indexed with each decision and status.
- **`docs/architecture/` is populated** — the Items section had been empty since
  v0.1.0. Three notes, all for invariants that had already cost real bugs:
  `var buf[N]` is bytes not slots (and what the recurring 144 / 4096 literals
  are); the four-way agnos FS-ABI split, including why agnos `sys_readdir` must
  **not** replace the `getdents` enumerator (its 64-byte records cap filenames
  at 63); and the bump-allocator lifetime model.
- Removed a dead line-scan in `_git_parse_ignore` — it computed an end-of-line
  offset nothing ever read, costing a second full scan per line.

### Tests

- **233 → 272 assertions.** New coverage for the sanitizer predicate across the
  C0 / DEL / printable / high-byte boundaries (including the `load8`-signedness
  regression guard), `_git_normalize_abs` across nine path shapes plus the
  `..`-is-preserved contract, CRLF vs LF `.gitignore` parsing, and negative-epoch
  `format_mtime` with the epoch-0 boundary asserted.

### Known / deferred

Recorded with rationale in the audit's "Deferred" table: `sys_write` return
values are still unchecked (56 sites — a full filesystem yields exit 0 with
truncated output); `-l` still stats every entry twice; `tests/darshini.fcyr` is
still a stub, so `cyrius fuzz` passes while executing zero darshini code; the
agnos directory enumerator still bump-allocates its scratch. None are
regressions; all are tracked for 1.4.0.

## [1.3.1] — v1.3.1: cycc 6.5.35 + darshana 1.0.0

Toolchain + dependency bump. The manifest pin had drifted a full
minor behind the installed wrapper (`6.4.24` vs `6.5.35` — 111
releases, warning on every build); this catches it up. darshana is
bumped `0.9.0` → **`1.0.0`**, its **API freeze** — the 29-function /
37-constant surface is now contract, so a future break costs upstream
a major bump plus its own ADR. Both symbols darshini calls
(`tty_sgr` / `tty_sgr_reset`) are inside the frozen set, so darshini's
sole external dep is now a stable target.

Patch bump: no darshini behavior change on any target, and no
call-site repair. The 0.9.3 pre-freeze breaks
(`tty_sgr_reset_buf` / `tty_dec_buf` gained a `-1` return, and the
four `AGNOS_*` constants were privatized to `_AGNOS_*`) touch zero
darshini call sites — verified by grep, not assumed. The same cut
refactored `tty_sgr` into a wrapper over `tty_sgr_buf` and collapsed
three copies of the decimal emitter into one `_ansi_emit_u8`; the
emitted bytes are unchanged, verified here at the wire rather than
taken from upstream's changelog.

Only functional source change is the lockstep `--version` string.

**Verified byte-for-byte.** A reference binary built from the v1.3.0
tree with cycc 6.4.24 + darshana 0.9.0 was diffed against the new
build across **77 comparisons on four build targets**: 26 listing
modes on a pipe, 27 under a real 80×24 pseudo-terminal (which is what
actually exercises the darshana escape path — the pipe runs never
emit a single SGR byte), 12 on the agnos target under `mirshi
--root`, and 12 on the aarch64 build under `qemu-aarch64`. Output is
identical in every one, escape sequences included. Fixture covers
dirs, symlinks, a broken link, a FIFO, an unreadable dir, a
magic-bytes ELF and PNG, a `.gitignore`d path, and modified /
untracked git states.

A 10-agent audit then swept the delta the A/B could not reach: the
111-release cycc changelog, the vendored-source diff at darshini's
call sites, and several hundred further probes covering filename
lengths to 255, CJK / combining / RTL / zero-width names, embedded
ESC and CSI bytes, 20k- and 120k-entry directories, 4,000-level
nesting, symlink loops, sizes to i64max, mtimes from epoch 0 to year
9999, setuid/setgid/sticky, terminal widths 0 to 65535, malformed
`.git` indexes (truncated, v3, v4, entry-count liars), and SIGPIPE
mid-listing. 60 candidate findings were raised and put through
adversarial refutation; **11 of the 12 material ones were killed**,
and the survivor was a stale sentence in
`docs/guides/getting-started.md`, fixed below. No defect in the
shipped binary.

The aarch64 row is a **no-regression** check, not a support claim.
That build still degrades to `?` placeholders for every stat-derived
column (`-l`, `-F`, `-T`, `--git`) because `walk.cyr`'s `lstat_path`
issues bare syscall 6, which is not `lstat` on aarch64 — the gotcha
state.md has carried since M1. It is byte-for-byte as broken after
this bump as before it, so the toolchain move neither fixed nor
worsened it. Linux x86_64 and agnos remain the supported targets.

Clean build on all three targets, `cyrius lint` free of non-cosmetic
warnings, `cyrius vet` 9 deps / 0 untrusted / 0 missing, fuzz harness
green, and 233/233 assertions passing.

### Fixed

- **CI could not install the pinned toolchain.** Both workflows
  hand-rolled the install — untar the release asset, `cp` into flat
  `$HOME/.cyrius/{bin,lib}` — which is the **pre-6.5 layout**. From
  6.5.x `cyrius deps` resolves the stdlib snapshot from
  `$HOME/.cyrius/versions/$CYRIUS_VERSION/lib` and hard-fails with
  `error: cyrius.cyml pins version 6.5.35 but it is not installed`,
  so every job died at dep resolution the moment the pin crossed
  6.5.0. Both blocks (`ci.yml` `build-and-test`, `release.yml`
  `package` — the only two jobs that invoke the toolchain) now pipe
  the pin to the upstream `scripts/install.sh`, which lays out
  `versions/<v>/{bin,lib}`, symlinks `bin/` + `lib/` at it, and adds
  the SHA256 + signature verification the hand-rolled block skipped.
  Matches darshana / patra / libro. The pin stays the single source
  of truth, per CLAUDE.md.

  Reproduced and fixed under simulation rather than inferred: the old
  `cp`-based block rebuilt into a scratch `CYRIUS_HOME` reproduces the
  reported error verbatim; the installer into a clean scratch
  `CYRIUS_HOME` yields `versions/6.5.35/lib` (102 files), and a
  `git ls-files` checkout of this tree run against it takes
  `cyrius deps` → lint → vet → build → 233/233 → all 14 smoke gates
  green.
- A new **Verify toolchain layout** step follows each install and
  fails loudly if `versions/<pin>/lib` is absent — so a
  successful-looking install that leaves no snapshot is caught at the
  install step instead of surfacing as a confusing dep-resolution
  error several steps later.

### Changed

- `cyrius.cyml` pin bumped `6.4.24` → `6.5.35`; `lib/` refreshed to
  the 6.5.35 snapshot (`cyrius lib sync --full`, 108 files). Traced
  to darshini's actual call sites rather than read off the diffstat:
  of the 10 vendored modules it pulls in, exactly **three** changed
  functions darshini calls.
  - `path_join` (2 sites — `tree.cyr:170`, `long.cyr:80`):
    signature-only, untyped params became `: Str`. Body unchanged;
    the untyped call sites still type-check.
  - `dir_list` (1 site — `walk.cyr`): same `: Str` annotation, plus
    cycc 6.5.11 moved its 4 KB `getdents` scratch from `alloc()` to a
    stack local. Since the default allocator is a bump allocator with
    no free, darshini's Linux listing path stops burning ~4 KB per
    directory — a free win.
  - `lib/string.cyr`'s `print_num` i64::MIN fix and `lib/args.cyr`'s
    comment edit affect nothing: darshini has no call site for either
    (it formats its own sizes and timestamps), and DCE drops them.

  Everything else in the range is additive or has zero darshini call
  sites — including `dir_walk`'s v6.5.12 symlink-descend loop guard
  and the two `_cfo` const-fold miscompile fixes, both real changes
  that darshini's source contains no instance of.
- `[deps.darshana]` tag bumped `0.9.0` → `1.0.0` — the upstream API
  freeze. Dep-bump-only for darshini.
- `--version` string → `darshini 1.3.1`.
- `docs/guides/getting-started.md` no longer tells readers that
  `cyrius bench` cannot auto-discover `tests/*.bcyr`. cycc **6.4.78**
  — inside this pin's range — made it walk `tests/` too, so bare
  `cyrius bench` now finds `tests/darshini.bcyr`. Verified in both
  directions: 6.4.24 reports "No benchmarks found", 6.5.35 discovers
  and runs all 13 cases. The explicit-path form still works and is
  what `docs/benchmarks.md` captured.
- `docs/development/state.md` records three findings the sweep
  verified but which are **not** defects introduced here: `-l`'s
  `format_mtime` reads chrono's `DateTime` by raw byte offset, a
  layout cycc 6.4.67 explicitly made private behind new accessors
  (additive this bump, so mtimes are byte-identical); darshini's
  agnos `_d_dir_list_agnos` still bump-allocates the 4 KB getdents
  scratch that cycc 6.5.11 moved to the stack for the Linux path it
  mirrors — an asymmetry this bump introduces; and agnos
  `sys_readdir` (#81, new in 6.4.44) must *not* replace darshini's
  `sys_getdents` (#29) enumerator, because its fixed 64-byte records
  cap filenames at 63 bytes. All three are left for their own cuts.

## [1.3.0] — 2026-07-08: agnos target support + cycc 6.4.24 / darshana 0.9.0

darshini now builds `cyrius build --agnos src/main.cyr` and **runs on
AGNOS under mirshi** — full listing across every mode (plain /
multi-column / `-l` / `-F` / `-T` / `--git` / `--mime`), not just a
launch. The port is entirely `#ifdef CYRIUS_TARGET_AGNOS`-gated, so the
Linux/macOS paths stay byte-identical (suite 233/233 unchanged). Ships
in the agnosticos agnos-dev docker image (`DELTA[dev]`). Minor bump: new
platform, zero CLI-contract or behavior change on existing targets.

The agnos work was a cascade of low-level FS-ABI divergences behind the
initial `SYS_GETCWD` build break — agnos has no ambient cwd, no
`ioctl`/`TIOCGWINSZ`, no `lstat`, and a different `getdents` ABI.

### Added

- **agnos target support.** `cyrius build --agnos` produces a static
  agnos ELF; verified end-to-end under mirshi (`--root`) across every
  listing mode. Added `darshini` to `agnosticos/docker/build-dev.sh`
  `DELTA[dev]`.
- Portable FS wrappers in `src/walk.cyr` (`d_stat` / `d_open_ro` /
  `d_lstat`) hiding the Linux-vs-agnos call-shape split: agnos
  `stat`/`open` take an explicit path length, and agnos has no lstat
  (#6 is `close`) so `d_lstat` falls back to `stat`. The `STAT_*` field
  offsets are already per-target in the stdlib, so field reads are
  untouched.
- `_d_dir_list_agnos` — a native agnos `getdents`(#29) enumerator that
  parses the packed `AgnosDirent` layout, since the stdlib `dir_list`
  is Linux-`getdents64`(#217)-only. `list_dir` dispatches per target.

### Changed

- `cyrius.cyml` pin bumped `6.2.22` → `6.4.24`; `lib/` refreshed to the
  6.4.24 snapshot (`cyrius lib sync --full`, 98 files).
- darshana dep bumped `0.7.1` → `0.9.0` — dep-bump-only; darshini's
  entire darshana surface is `tty_sgr` / `tty_sgr_reset`, both
  unchanged across the 0.7→0.9 line (the 0.8/0.9 additions are agnos
  TTY peers for full-screen TUI consumers darshini never calls).
- `--version` string → `darshini 1.3.0`.

### Fixed

- `_git_make_absolute` (`--git`): the Linux `getcwd(2)` path is now
  gated Linux-only. On agnos (no ambient cwd) an absolute listing path
  works fully; a relative one gracefully omits the git column, matching
  the existing out-of-repo behavior.
- `term_width`: no agnos `ioctl`/`TIOCGWINSZ`, so it returns 0 (the
  same pipe/non-TTY sentinel) → single-column, decoration-free output
  instead of failing to build.
- `ENOENT` / `EACCES` defined for the agnos build (they are Linux-enum
  -only; agnos reports a flat `-1` on failure, so the fine-grained
  error branches simply fall through to the generic message there).

## [1.2.1] — v1.2.1: cycc 6.2.22 + darshana 0.7.1

Toolchain bump. The installed cycc wrapper had moved to `6.2.22`
while the manifest pin stayed at `6.1.26` (drift warning on every
build); this catches the manifest back up. darshana is bumped
`0.7.0` → `0.7.1`, itself a **toolchain-only** upstream release
(no source / public-API change, module bodies byte-identical,
regenerated only to stamp the `6.2.22` header) — so darshini's
color path stays byte-identical and no call-site repair is needed.
Patch bump: no darshana surface move this time (unlike 1.2.0), no
darshini behavior change. The only functional source change is the
lockstep `--version` string. Verified: clean build + 233/233
assertions green.

### Changed

- `cyrius.cyml` pin bumped `6.1.26` → `6.2.22` (catches the
  manifest up to the installed wrapper; clears the pin-drift
  warning).
- `[deps.darshana]` tag bumped `0.7.0` → `0.7.1` (toolchain-only
  upstream; darshini's color path byte-identical).
- `lib/` refreshed to the 6.2.22 snapshot.

## [1.2.0] — v1.2.0: darshana 0.7.0 (breaking upstream) + cycc 6.1.26

Minor bump to absorb darshana's pre-freeze API-reshaping cut.
darshana **0.7.0 is a breaking release**, but every breaking
change lands on a symbol darshini does not call:

- `tty_cooked(fd)` → `tty_cooked()` (zero-arg)
- `tty_itoa` → `tty_dec_buf` (renamed + return harmonized)
- `tty_clear_to_end` → `tty_clear_to_eos`
- `tty_apply_raw_flags` → `_tty_apply_raw_flags` (privatized)

darshini's entire darshana surface is `tty_sgr` / `tty_sgr_reset`,
both unchanged — so this upgrade needs **no call-site repair**
(same category as darshana's anuenue/bannermanor consumers).
Verified: clean build + 233/233 assertions green against 0.7.0.
darshini's own CLI contract is unchanged (non-breaking under the
M10 freeze); the minor bump reflects the significant dependency
major-surface move, not a darshini behavior change. The only
functional source change is the lockstep `--version` string.

### Changed

- `[deps.darshana]` tag bumped `0.6.0` → `0.7.0` (breaking
  upstream; darshini's call sites unaffected — `tty_sgr` /
  `tty_sgr_reset` unchanged).
- `cyrius.cyml` pin bumped `6.1.24` → `6.1.26`.
- `lib/` refreshed via `cyrius update` to the 6.1.26 snapshot.

## [1.1.4] — v1.1.4: darshana 0.6.0 dep bump

Dependency-only release. `[deps.darshana]` tag bumped `0.5.4` →
`0.6.0` — an upstream **test-only** release (in-repo PTY harness;
no `src/` change, no public-surface change), so darshini's color
path is byte-identical. No functional source change here either
(only the lockstep `--version` string bump). Build clean and all
233 assertions green. Non-breaking under the M10 freeze.

### Changed

- `[deps.darshana]` tag bumped `0.5.4` → `0.6.0` (test-only
  upstream release; no API change).

## [1.1.3] — v1.1.3: toolchain bump

Pure version-pin release; no functional source changes (only the
lockstep `--version` string bump). Catches darshini up
to the ecosystem-wide cycc pin — the `cyrius` wrapper had already
drifted to `6.1.24` while the manifest pin sat stale at `6.0.0`.
`cyrius update` refreshed `lib/` (101 files) from the matching
snapshot; no source edits required. darshana bumped `0.5.3` →
`0.5.4` (itself a pure toolchain bump to the same 6.1.24 pin, no
API surface change). Build clean and all 233 assertions green on
the new toolchain. Non-breaking under the M10 freeze.

### Changed

- `cyrius.cyml` pin bumped `6.0.0` → `6.1.24`.
- `[deps.darshana]` tag bumped `0.5.3` → `0.5.4` (toolchain-bump
  release; no API change).
- `lib/` refreshed via `cyrius update` to the 6.1.24 snapshot.

## [1.1.2] — v1.1.2: hot-path optimizations

Three perf wins from the v1.2 candidates list in
[`docs/benchmarks.md`](docs/benchmarks.md). No behavior
change; non-breaking under the M10 freeze. 233/233 tests
holding.

### Performance

- **Hybrid sort** — insertion-sort cutoff at merge-sort
  leaves (< 16 elements). Standard optimization shipped by
  Java's `Arrays.sort` and libstdc++ `std::sort`. Restores
  best-case perf at small N (already-sorted 1k:
  635 µs → 493 µs, 1.3× faster). Slight regression on the
  fully-reverse-sorted worst case (640 µs → 820 µs) —
  accepted: real-world directories are nearly-sorted, not
  adversarial; absolute still well under any perception
  threshold and still **44× faster than v1.0**.
- **`pick_cols` widest-aware short-circuit** — pre-scans
  the widest entry; if it doesn't fit in `term_width`,
  returns 1 col immediately, skipping the entire per-col
  iteration loop. Bench `pick_cols 1k@10
  widest-doesnt-fit`: 33 µs (was a full iteration).
  Cap stays loose (1-char per col) — see source NOTE for
  why a widest-uniform cap would reject valid jagged
  layouts.
- **`_path_join_into` buffer reuse** — new local helper
  in `src/color.cyr` writes `dir + "/" + name + "\0"` into
  a caller-allocated cstr buffer. `compute_decor` allocates
  one 4096-byte buf per listing and reuses across entries
  instead of N str_builder allocations. **4.2× faster**
  per call (305 ns → 72 ns). lib/fs.cyr's `path_join` stays
  for tree.cyr's recursion (each frame needs its own
  persistent allocation).

### Notes

- v1.1.2 closes out the entirety of the v1.2+ hot-path
  optimization candidates from `docs/benchmarks.md`. v1.2
  backlog is now just mtime localization + post-v1 platforms.
- New bench coverage: `pick_cols 1k@10 widest-doesnt-fit`,
  `path_join (str_builder)`, `_path_join_into (buf reuse)`.
- No new tests; the changes are pure perf (no observable
  behavior). Existing tests confirm no regression (caught
  one tighter-cap bug in pick_cols mid-implementation —
  loosened back to 1-char min-per-col, kept the
  widest-doesn't-fit short-circuit).

## [1.1.1] — v1.1.1: multi-path argv

### Added

- **Multi-path argv** — `darshini path1 path2 path3 ...`. Per
  path classification + ls(1)-style ordering:
  1. Errors are emitted to stderr (process continues + exits 1).
  2. Non-directory paths render together in argv order, no
     header.
  3. Directory paths each get a `<path>:` header (when more
     than one path is in play) and a blank line between
     sections.
- `-d` short-circuits the file/dir split: each path renders as
  a single entry, no headers, no blanks. With `-F` adds the
  trailing `/`. Retires the maintainer's `ldir` / `lldir`
  shell-glob aliases — `darshini -d */` and
  `darshini -ld */` now both work.
- `-T` per-path tree with a blank line between trees (the
  tree's root line already names the path, so no extra header).
- Single-path invocations are byte-identical to v1.1.0 — no
  header, no behavior shift.

### Changed

- `parse_cli` now populates a caller-allocated `vec<cstr>` of
  positional args instead of writing a single `out_path`. Empty
  vec → `run_all` defaults to `"."`.
- Exit code propagation: partial-failure (one path errors, others
  succeed) returns 1. Matches `ls` behavior.

### Dotfile retirement complete

The maintainer's `~/.config/zsh/.aliases.zsh` migration: all
six original eza aliases now run through darshini.

- `ll = darshini -l --git`
- `l = darshini`
- `lfiles = darshini -F`
- `llfiles = darshini -lF --git`
- `ldir = darshini -d */` (was `eza -d */`)
- `lldir = darshini -ld */` (was `eza -ld */`)

### Notes

- Multi-path support was originally slated for v1.2 alongside
  mtime localization + platform work; pulled forward this
  release to close the dotfile-migration story.
- Tests stayed at 233/233 (unit tests don't touch the
  per-path orchestrator; multi-path covered by new CI smoke).
- v1.2 backlog now: mtime localization + post-v1 platforms
  (aarch64 Linux → macOS / BSD / Windows). Other items
  remain on the v1.2+ perf-candidates list per
  [docs/benchmarks.md](docs/benchmarks.md).

## [1.1.0] — v1.1: backlog burndown

Pure additions + internal upgrades, all non-breaking under the
M10 freeze contract.

### Added

- `--help` — flag summary + exits 0. Back-fills the M10
  roadmap omission.
- `--version` — prints `darshini 1.1.0` + exits 0. Same back-fill.
- `-F` — classify entries with POSIX-style trailing indicator:
  `/` directory, `*` executable regular file, `@` symlink,
  `|` fifo, `=` socket. Block / char devices have no POSIX
  indicator and don't emit one. Composes with every existing
  format (long / multi-column / single-column / tree).
  Display-width: 1 cell per entry (with-or-without indicator;
  padding reserves the cell for alignment).
- `-d` — list the path as a single entry instead of listing its
  contents (matches `ls -d` shape). Composes with `-l` (single
  long-format row) and `-F` (trailing `/` for directories).
  Multi-path support (`-d dir1 dir2 ...`) stays out of scope —
  v1.2 candidate.

### Performance

- `sort_entries` upgraded from insertion sort → top-down
  merge-sort. Stable, O(N log N) worst case (was O(N²)).
  Bench delta:
  - 1k reverse-sorted entries: **36.3 ms → 640 µs (56× faster)**
  - 100 reverse-sorted entries: 391 µs → 48 µs (8× faster)
  - 1k already-sorted: 114 µs → 635 µs (5.6× slower —
    overhead of the auxiliary vec; absolute still sub-ms, well
    under any perception threshold)
  Caller contract unchanged; allocates O(N) scratch internally.
- `_git_find_tracked` upgraded from O(N) linear scan → O(1)
  average hashmap lookup. Built once at `git_open` time, lives
  on the `GitCtx`. Quadratic → linear total cost for repos with
  thousands of tracked files. Invisible on this repo's 117-file
  index (sub-µs either way); matters at scale.

### Internal

- `cyrius.cyml` [deps].stdlib gains `hashmap`.
- `GitCtx` struct grew 40 → 48 bytes (new `tracked_map` slot
  at +40).
- `emit_decorated` and the four render-path entry points
  (`print_entries`, `render_columns`, `render_long`,
  `render_long_one`, `render_tree`) gained `classify_char` +
  `classify_pad` params. `compute_decor` gained a parallel
  `classifies` vec at +32.

### Dotfile retirement progress

The maintainer's `~/.config/zsh/.aliases.zsh` migration
continues. v1.0 retired `ll` and `l`; v1.1 retires `lfiles`
and `llfiles` via the new `-F` flag. `ldir` / `lldir` need
multi-path argv support (v1.2 candidate); they stay on eza
until then.

### Notes

- v1.1 is a SemVer-minor bump per the new flags. The M10
  freeze contract holds — no behavior changed for any v1.0
  flag, only additions.
- Tests stayed at 233/233. New flags don't add their own
  test functions (they thread through existing emit code
  whose contracts didn't change); their effects are
  exercised end-to-end via the binary in CI smokes.
- v1.2 backlog (per user direction): mtime localization,
  multi-path argv, post-v1 platforms (aarch64 Linux first,
  then macOS / BSD / Windows).

## [1.0.0] — M10: v1.0 freeze

### Breaking

The **CLI flag surface is now frozen**. Future releases under
the 1.x line will not change the meaning, removal, or
default-on-or-off behavior of any of:

- `-l` / `-h` / `-1` / `-T` / `--tree` / `--level N`
- `--git` / `--mime` / `--no-color` / `--no-icons`

Frozen behaviors per ADR:
- Color palette + per-file-type assignment —
  [ADR 0001](docs/adr/0001-color-scheme.md)
- Icon glyph schema + lookup precedence —
  [ADR 0002](docs/adr/0002-icon-format.md)
- Mime detection precedence + magic-byte set —
  [ADR 0003](docs/adr/0003-mime-detection.md)
- Tree-mode connector charset + composition rules —
  [ADR 0004](docs/adr/0004-tree-mode.md)

Frozen defaults:
- Pipe-aware: stdout-not-a-TTY suppresses columns / color /
  icons / mime automatically.
- Case-insensitive alphabetical sort, locale-free.
- mtime in UTC under `-l` (post-v1 will add localization
  without breaking the UTC default).
- Symlink-to-dir not followed under `-T`.

Adding new flags is non-breaking. Changing the meaning of any
existing flag is a breaking change requiring a 2.x bump.

### Added

- v1.0.0 release notes (this entry) — declares the freeze.

### Notes

- No source changes vs v0.9.1. The freeze IS the contract
  change per Keep-a-Changelog rationale.
- Platforms — Linux x86_64 only through 1.x. Other platforms
  remain post-v1 (separate version line, not blocked on this
  freeze).
- Three minor findings from the [2026-05-23 audit](docs/audit/2026-05-23-audit.md)
  remain on the v1.1+ enhancement backlog
  (`sort_entries` merge-sort upgrade, git tracked-set hashmap,
  per-listing alloc-arena reset). None block v1.0.
- v1.1 candidates surfaced from the maintainer's dotfile
  migration: `-F` (classify) and `-d` (list-dir-as-self) to
  retire the remaining `eza` aliases (`lfiles`, `llfiles`,
  `ldir`, `lldir`).
- v1.1 candidate from M2 notes: mtime localization without
  losing the UTC default.

## [0.9.1] — M9: pre-v1 audit sweep

### Added
- [`docs/audit/2026-05-23-audit.md`](docs/audit/2026-05-23-audit.md)
  — full P(-1) hardening pass: cleanliness sweep, internal
  code review (var-buf sizing, syscall error paths, path
  traversal, external-format parser robustness, allocation
  patterns, integer overflow), external research (eza
  feature catalog with deliberate-omission decisions),
  documentation audit. 0 critical / 0 major / 3 minor
  findings — all accepted as v1.1+ enhancements.
- [`docs/benchmarks.md`](docs/benchmarks.md) — bench
  baseline captured at v0.9.0. Typical-listing total
  ~120 µs algorithmic + ~300-500 µs stat I/O. Worst-case
  1k-reverse `sort_entries` 36 ms (flagged as v1.1
  optimization candidate).
- `tests/darshini.bcyr` — real benchmark suite replacing
  the M0 noop stub. 10 benches across `sort_entries`
  (best/worst), `pick_cols`, `color_for_mode`,
  `icon_for_entry`, `mime_for_entry`. Reproducible via
  `cyrius bench tests/darshini.bcyr`.
- [`docs/adr/0004-tree-mode.md`](docs/adr/0004-tree-mode.md)
  — back-filled per CLAUDE.md P(-1) "tree-mode ADR"
  requirement. Documents the connector charset, recursion
  contract, composition rules with `-l` / `--git` /
  `--mime`, and the alternatives-considered list.

### Notes
- No source changes — audit was read-only review + docs.
- v0.9.1 is the pre-freeze checkpoint. v1.0.0 is the
  contract-freeze tag with no behavior changes.

## [0.9.0] — M8: `--mime` type column

### Added
- `--mime`: per-entry mime type, shown as a left-aligned
  column under `-l` (only under `-l` — see ADR 0003 for
  why short / multi-column / tree formats don't get it).
- Detection precedence (per ADR 0003, intentionally
  diverging from the roadmap's literal "magic-first" text
  for cost reasons):
  1. Non-regular file type → `inode/*` (directory / symlink /
     fifo / socket / blockdev / chardevice).
  2. Exact `[filenames]` match (Makefile, Dockerfile, LICENSE,
     VERSION, README, CHANGELOG, .gitignore, .gitattributes).
  3. Lowercased `[extensions]` match (80+ entries, mirrors
     icons/default.cyml shape).
  4. Executable bit set on a regular file →
     `application/x-executable`.
  5. Magic-bytes probe (open + read 16 bytes): ELF / PNG /
     JPEG / GIF / ZIP / gzip / bzip2 / xz / 7z / PDF / shebang.
  6. Fallback → `application/octet-stream`.
- `docs/adr/0003-mime-detection.md` — third ADR. Documents
  the precedence divergence + magic-byte set + why
  `--mime` is `-l`-only at v1.0.
- `mime/default.cyml` — human-readable mime mapping (source
  of truth for the compile-baked table in `src/mime.cyr`,
  same pattern as ADR 0002 for icons).
- `src/mime.cyr` — `mime_for_entry` master + the four
  per-precedence-tier helpers.
- `src/color.cyr` `compute_decor` extended again: now also
  produces a parallel `mimes` vec when requested. Single
  lstat pass still covers all four decoration vecs (colors,
  icons, git, mimes).
- `src/long.cyr` `render_long` two-pass for mime: first
  scan finds max mime width, second emits each row with
  the mime column left-aligned + padded.
- Tests: 36 new assertions across `_mime_for_inode`,
  `_mime_for_filename` (exact-only, not prefix),
  `_mime_for_ext`, `_mime_for_magic_bytes` (synthetic
  byte buffers per signature), `mime_for_entry` full
  precedence chain. Total now 233/233.

### Notes
- `--mime` without `-l` is parsed but silent (no column).
  Column placement under short / multi-column / tree
  would clash with the fixed-width prefix budget those
  layouts rely on. Future fixed-width-truncated variant
  is a post-v1 enhancement if asked.
- Cost ceiling: 0 extra opens for entries with a known
  extension (~95% of typical listings). 1 open + read(16)
  + close per extensionless non-executable regular file.
- `application/zip` mime covers JAR / DOCX / ODT containers
  too. Acceptable v1.0 imprecision; deeper inspection
  needs unzipping (out of scope).
- README / CHANGELOG / LICENSE filenames are EXACT-match
  only here (in contrast to icons.cyr's filename
  prefixes) — so `README.md` correctly reports
  `text/markdown`, not `text/plain`.

## [0.8.0] — M7: `--git` status column

### Added
- `--git`: per-entry git status, read directly from
  `.git/index` (v2 binary) + `.gitignore` +
  `.git/info/exclude`. NO `git` subprocess per the
  CLAUDE.md hard rule — every byte parsed from
  on-disk files via sys_open + sys_read.
- Status chars (single char, 2-cell column with trailing
  space): `.` tracked (clean), `M` tracked (modified —
  mtime_sec or size differs from index), `?` untracked,
  `!` ignored.
- Directory entries aggregate: a directory is shown as
  tracked (`.`) when ANY indexed path lives under it
  (git's index has no directory entries, only files).
- Silent skip outside a git repo: when `.git/` isn't
  in the ancestor chain, `--git` is a no-op (no column,
  no error). Acceptance criterion per roadmap M7.
- Composes with `-l` (column slots after mtime, before
  the icon/name decoration), short / multi-column modes
  (decoration prefix), and tree mode (per-entry).
- `src/git.cyr` — big-endian decode helpers, `.git/index`
  v2 parser, minimal `.gitignore` parser (exact basename,
  `*suffix` glob, `dir/` directory-only), `git_open`
  top-level (find root → load context), `git_status_for`
  classifier with directory-aggregate semantics.
- `src/color.cyr` `compute_decor` extended: single lstat
  pass now also produces the git_status vec when a
  GitCtx is supplied. `emit_decorated` gains
  `(git_char, git_pad)` params; old `emit_colored` shim
  forwards 0s.
- Cell-width math: `pick_cols` / `_columns_total_width`
  treat `--git`'s 2-cell prefix the same way they treat
  icons — uniform per-cell offset, padding diff
  unaffected.
- Tests: 23 new assertions across `_be_u32` / `_be_u16`
  (multi-byte big-endian decode), `_git_parse_index`
  (header validation, version check, empty index),
  `_git_match_one` (exact / suffix-glob / dir-only),
  `_git_listing_rel` (prefix-strip edge cases). Total
  now 197/197.

### Notes
- MVP scope: `.git/index` v2 only (v3+ rejected; index-v4
  path-compression unsupported). Linear-scan lookup of
  tracked paths (acceptable through low-thousands files;
  hashmap upgrade is post-v1). `.gitignore` subset:
  exact-basename + `*<suffix>` + `dir/`. Skips negation
  (`!`), brace expansion, mid-string globs, `**`
  deep-match. Full gitignore semantics would 5x the
  module size; v1.0 ships the 80% case.
- "Added/staged-vs-HEAD" distinction not shown — would
  require HEAD object parsing. Treated as tracked.
  Defer to post-v1.
- nsec-precision modification check skipped (filesystems
  often return 0 nsec, would false-flag clean files).
  Only `mtime_sec` and `size` are compared.
- The `.git/` directory itself shows as `?` (not in
  index, not in .gitignore). Acceptable; eza skips it
  with a built-in but darshini stays uniform.
- ADR not authored for M7 — git format is the
  upstream-frozen contract, no original design decisions
  worth documenting (in contrast to ADRs 0001/0002).
  The scope-cuts above are the audit trail.

## [0.7.0] — M6: tree mode (`-T` / `--tree`)

### Added
- `-T` / `--tree`: recursive box-drawn display.
  `tree(1)`-style connectors: `├──` for non-last siblings,
  `└──` for the last, `│` for still-continuing ancestors,
  spaces for finished ones. Standard Unicode box-drawing
  (U+251C/2514/2502/2500).
- `--level N`: cap recursion depth at N levels. Value
  parses as a positive integer in the next argv slot
  (`darshini -T --level 2 docs` shape — matches `tree
  --level` / `eza --level`). Without `--level`, recurses
  to the bottom.
- `-T` composes with `-l`: long-format columns
  (perms / size / mtime) prefix the tree connector +
  name. Composes with `-h` for human-readable sizes,
  `--no-color` / `--no-icons` for plain output.
- Symlink-to-dir handling: tree does NOT recurse into
  symlinked directories (matches `tree(1)` / `eza` default;
  an opt-in follow flag is out of scope for v1.0 per the
  M10 frozen flag set).
- `src/tree.cyr` — `render_tree(root, max_depth, want_long,
  want_human, want_color, want_icons)` top-level entry +
  the depth-stack recursion (`_tree_recurse`).
  Testable helpers `_tree_prefix_buf` /
  `_tree_connector_buf` write the byte sequences into a
  caller buffer for direct assertion.
- `src/main.cyr` — argv parser learns `-T` (short) /
  `--tree` (long) / `--level N` (long with required int
  value). `_parse_pos_int` validates non-empty digit-only
  cstr; rejects empty / signed / non-digit input.
- Tests: 28 new assertions across `_tree_connector_buf`
  (exact bytes for both is_last variants), `_tree_prefix_buf`
  (empty / single-slot / mixed depth-stack patterns),
  `_parse_pos_int` (positive ints, zero, empty, negative,
  mid-string non-digit). Total now 174/174.

### Notes
- Size column in `-T -l` is not max-aware (each row emits
  the natural-width size). The tree's vertical structure
  provides enough visual rhythm; a two-pass walk to compute
  max-size-per-subtree was deemed over-engineering for v1.0.
- Box-drawing characters render correctly in any modern
  UTF-8 terminal — no Nerd Font assumption (icons remain
  separate, gated by `--no-icons`). No ASCII fallback flag
  at v1.0 (`tree(1)`'s `--charset=ascii` equivalent); revisit
  post-v1 if a serial-console / dumb-terminal user asks.
- `-1` under `-T` is a no-op: tree mode is inherently
  one-entry-per-line. Doesn't error — the bundling stays
  forgiving.

## [0.6.0] — M5: icons via CYML mapping

### Added
- Per-entry icons on TTY output. Lookup precedence per
  ADR 0002: exact filename → filename prefix → file-type
  override → extension match → generic file glyph. Every
  entry gets a glyph (no "blank" cells).
- `--no-icons`: long-form flag to force-off even on a TTY.
  Bundles fine with the rest of the v0.6.0 flag set.
- Pipe-aware default: stdout-not-a-TTY → no icons (no bytes
  emitted, no column-budget impact). Same gate as M3 columns
  and M4 color.
- `icons/default.cyml` — human-readable source of truth for
  the icon mapping. Nerd Font v3+ glyphs across Devicons,
  Material, Font Awesome, Octicons. 80+ extensions, 7 exact
  filenames, 5 filename prefixes.
- `src/icons.cyr` — compile-baked lookup chain mirroring
  `icons/default.cyml`. `icon_for_entry(name, mode)` returns
  the glyph cstr (or 0 on stat-failed entries).
  `icon_display_width()` returns the fixed 2-cell budget per
  ADR 0002.
- `docs/adr/0002-icon-format.md` — second ADR. Locks the
  schema, the lookup precedence, the display-width
  assumption, and the compile-baked-vs-runtime-CYML decision.
- `src/color.cyr` — `compute_decor(entries, dir_str,
  want_color, want_icons)` replaces `compute_colors`. Single
  lstat pass over the entry list now produces both the colors
  vec and the icons vec (down from 2N lstats to N when both
  decorations are on).
- `emit_decorated(name, color, icon, icon_pad)` — extended
  emit primitive; covers the bare-name, name-with-color,
  name-with-icon, and name-with-both shapes. Old
  `emit_colored` kept as a thin wrapper.
- Column-fit math: `pick_cols(entries, tw, icon_width)` and
  `_columns_total_width(..., icon_width)` take a fixed
  per-cell offset when icons are enabled. Padding diff
  unchanged (icon_width is uniform across the column).
- Tests: 25 new assertions across `icon_display_width`,
  `icon_for_entry` (each lookup precedence rule), and
  `pick_cols + icon_width` interactions. Total now 132/132.

### Notes
- Icon glyphs require a Nerd Font v3+ patched font on the
  user's terminal. Terminals without one render replacement
  characters; the documented fallback is `--no-icons`. No
  auto-detection — terminal-query for font availability isn't
  reliable across emulators.
- `icons/default.cyml` is the spec but is NOT parsed at
  runtime. The mapping is compile-baked into `src/icons.cyr`
  for startup speed (rationale in ADR 0002). When adding an
  icon, edit BOTH files. Runtime CYML loading is a v1.1
  candidate.
- Per-icon color overrides (LS_COLORS-style) deferred to v1.1.
  Each icon takes the name's mode color per ADR 0001.
- File-type icons (folder, link, fifo, ...) are hard-coded in
  `src/icons.cyr` rather than in the CYML — could lift to a
  `[type_overrides]` table when runtime-CYML lands.

## [0.5.0] — M4: color via darshana

### Added
- Per-entry color on TTY output. File-type detection drives the
  ADR-0001 palette: directory → blue, symlink (live) → cyan,
  symlink (broken) → red, executable regular file → green,
  fifo → yellow, socket → bright magenta, block / char device
  → bright yellow, regular non-executable → no color.
- `--no-color`: long-form flag to force-off even on a TTY.
  Bundles parse-fine with other short flags (`-l --no-color`).
- Pipe-aware default: stdout-not-a-TTY → no color (no escape
  bytes emitted). Same gate as M3's single-column-on-pipe.
- Broken-symlink detection: symlinks pay an extra `sys_stat`
  per entry to distinguish broken (red) from live (cyan). Cost
  scales with symlink count, not entry count.
- `src/color.cyr` — `color_for_mode(mode)` pure picker,
  `compute_colors(entries, dir_str)` parallel-vec builder with
  broken-symlink follow, `emit_colored(name, color)` write wrap.
- `docs/adr/0001-color-scheme.md` — first ADR. Frozen palette
  for v1.0, divergence-vs-`ls` notes, accessibility rationale.
- `[deps.darshana]` — first external dep, pinned at 0.5.3. All
  ANSI escapes route through `tty_sgr` / `tty_sgr_reset` per
  the CLAUDE.md "no raw ANSI inline" hard rule.
- Tests: 14 new assertions on `color_for_mode` (every file
  type → its SGR code). Total now 107/107.

### Notes
- The 8/16-color named-color subset is the v1.0 contract. 256
  / 24-bit truecolor primitives are available in darshana but
  unused — keeps the palette portable across serial consoles,
  tmux scrollback, screen readers, log archives.
- `NO_COLOR` / `CLICOLOR` env-var honors aren't wired. `--no-color`
  covers the explicit override; TTY detection covers script
  safety. Env-var support is a follow-up if downstream asks.
- LS_COLORS-style dotfile config is out-of-scope per roadmap.

## [0.4.0] — M3: multi-column auto-layout + `-1`

### Added
- Multi-column auto-layout: bare `darshini` on a TTY now packs
  entries into as many columns as fit, vertically-then-
  horizontally (`ls`-default shape). 2-space separator,
  per-column max width, partial trailing rows don't emit
  trailing whitespace.
- `-1` / `--single`: force single-column output even on a TTY.
  Matches `ls -1` semantics. Bundles with `-l` / `-h` (e.g.
  `-1l` is well-formed; `-l` wins).
- Pipe-aware default: stdout-not-a-TTY → single column. Probed
  via `ioctl(TIOCGWINSZ)`; failed ioctl → 0 → single column.
  TTY-reports-0-cols → 80-col fallback per roadmap.
- `src/columns.cyr` — `term_width()`, `pick_cols(entries, tw)`,
  `render_columns(entries, tw)`. The picker rejects phantom
  layouts where the trailing column would be entirely empty
  (e.g. 5 entries × "4 cols × 2 rows" really only fills 3 cols).
- Tests: 19 new assertions across `pick_cols` (uniform 5/100/1000-
  entry vecs, jagged widths, degenerate inputs, narrow TTYs)
  and `_columns_total_width` (exact byte width for known
  layouts). Total now 93/93.

### Notes
- Vertical-then-horizontal is the contract per roadmap; column-
  major fill (`ls -x`) is out of scope for v1.0.
- `COLUMNS` env-var override (which `ls` honors) isn't wired —
  defer; ioctl is the single source of truth right now.
- M3 doesn't change `-l` behavior — long-format rows are always
  one per line, columns kick in only on the default short-form
  path.

## [0.3.0] — M2: `-l` long format + `-h` human-readable sizes

### Added
- `-l` / `--long`: long-format rows — `permissions size mtime name`,
  size right-aligned within the listing's max-size width.
- `-h` / `--human`: IEC-style 1024-based size buckets — `X.YK`,
  `X.YM`, `X.YG`, `X.YT`. Sub-1K stays plain decimal. Modifier
  only; without `-l` it's a no-op (no size column shown anyway,
  matching `ls -h` semantics).
- Bundled short flags: `-lh` and `-hl` both work.
- `-l <file>`: under `-l`, a non-directory path renders as a
  single long row (matching `ls -l <file>` shape) instead of
  echoing the bare path.
- `src/long.cyr` — long-format orchestrator. Two-pass: collect
  per-row stat + size-string, then emit with size column
  right-aligned to the listing-wide max. Uses lstat (not stat)
  so symlinks render as themselves rather than their targets.
- `src/render.cyr` — adds `format_perms` (10-byte ls -l shape,
  including setuid/setgid/sticky upper+lower variants),
  `format_size_decimal`, `format_size_human` (decimal +
  IEC 1024-based), `format_mtime` (`YYYY-MM-DD HH:MM`, UTC).
- `src/walk.cyr` — adds `lstat_path` (bare syscall 6, no follow)
  and the `ModeBit` enum (POSIX `S_IF*` / `S_I*` constants).
- `cyrius.cyml` [deps].stdlib gains `chrono` (auto-included).
- Tests: 44 new assertions across `format_perms`,
  `format_size_decimal`, `format_size_human`, `format_mtime`.
  Total now 74/74.

### Notes
- Mtime is **UTC**, not local — matches the v1.0 contract
  ("locale-free, stable"). `ls -l` shows local time so darshini's
  output may differ by your tz offset. Documenting; not changing.
- Setuid / setgid / sticky bits render with the standard
  upper/lower convention: `s`/`S` (setuid + x / no x), same
  for setgid, `t`/`T` for sticky.
- Stat-failed rows (broken symlinks etc.) render with `?`
  placeholders so column alignment survives.
- M2 is Linux x86_64 only — `lstat_path` uses syscall 6 directly
  (no portable wrapper in stdlib yet). aarch64 dispatch needs an
  at-family detour through `newfstatat` — follow-up.
- M2 doesn't yet render symlink targets (`-> target` tail). That
  pairs with the symlink-display ADR work planned alongside
  M6 / M7.

## [0.2.0] — M1: directory walk + basic listing

### Added
- `darshini` lists the current directory, one entry per line, sorted
  case-insensitively. Acceptance for [M1 in the roadmap](docs/development/roadmap.md).
- `darshini <path>` — lists `<path>` if it's a directory; echoes
  the path if it's a regular file (matches `ls FILE` semantics).
- Error reporting on stat failure: `darshini: <path>: <reason>` to
  stderr, exit 1. Reasons surfaced separately: `no such file or
  directory` (ENOENT), `permission denied` (EACCES), `cannot stat`
  (everything else). `permission denied` on a stat-able but
  unreadable directory is surfaced via an explicit open probe in
  `check_dir_readable` because `dir_list` swallows open failures.
- `src/render.cyr` — display primitives: `lower_byte`,
  `str_lt_ci`, `sort_entries` (in-place insertion sort over
  vec<Str>), `print_entries`.
- `src/walk.cyr` — filesystem primitives: `classify_path`
  (sys_stat-based dir/non-dir/errno discriminator),
  `check_dir_readable` (sys_open probe), `list_dir` (dir_list wrap).
- `tests/darshini.tcyr` — 30 assertions across `lower_byte`,
  `str_lt_ci`, `sort_entries`, `classify_path`, `check_dir_readable`.
- `cyrius.cyml` [deps].stdlib gains `args` + `fs` (auto-included).

### Notes
- M1 is Linux x86_64 only — `classify_path` uses the x86_64 stat
  struct layout (144 bytes, `st_mode` at +24); aarch64 dispatch
  follows in a later cycle through the existing `Stat` enum.
- `var buf[N]` in Cyrius 6.0.x allocates N **bytes**, not N i64
  slots (the language guide is misleading; the bisect cost an
  afternoon — feedback memory filed). `classify_path` sizes its
  stat buffer as `var buf[144]` per `STAT_BUFSZ`.
- No darshana / colors / icons yet — those land at M4 / M5.

## [0.1.0]

### Added
- Initial project scaffold

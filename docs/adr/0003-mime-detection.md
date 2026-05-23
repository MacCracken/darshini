# ADR 0003 — mime type detection

**Status**: accepted
**Date**: 2026-05-23
**Milestone**: M8 (v0.9.0)

## Context

M8 lands the `--mime` column. The roadmap pins the shape:
> `--mime` flag — extra column showing detected mime type.
> Detection via magic-bytes table (CYML-defined; ships in
> `mime/`). Falls back to extension lookup when magic-bytes
> inconclusive.

This ADR locks:
1. Detection precedence (magic-first vs extension-first)
2. Magic-bytes v1.0 signature set
3. `mime/default.cyml` schema + compile-baked-vs-runtime decision
4. Column placement (long format only vs everywhere)
5. Per-entry cost ceiling

## Decision

### Detection precedence

Diverging from the roadmap's literal text: **extension-first,
magic-bytes for the extension-less / unknown-extension /
executable-bit-set tail**.

Order:
1. Non-regular file type (directory / symlink / fifo / socket /
   block dev / char dev) → `inode/*` mime per IANA.
2. Regular file with an extension in the table → extension's
   mapped mime.
3. Regular file, no extension match, executable bit set →
   `application/x-executable` (skip magic).
4. Regular file, no extension match, not executable → open +
   read first 16 bytes, magic-byte dispatch.
5. Default → `application/octet-stream`.

Why diverge from "magic-first":
- Roadmap's order makes `--mime` cost N opens for every listing.
  For a 1000-entry directory that's 1000 syscalls before the
  first byte renders. Unacceptable for a daily-use tool.
- Extension-first matches `file(1)`'s `--mime-encoding=...`
  behavior when `--mime` is passed without `--apple` flags
  (file actually does magic-first, but with libmagic caching
  the cost is amortized — we have no such cache).
- The extension table covers ~95% of real-world cases. Magic
  bytes are the safety net for the genuinely-extensionless
  files (binaries, scripts without `.sh`, etc.).
- Executables are mode-bit detectable for free. No magic
  needed for the most-common extensionless case.

### Magic-bytes set (v1.0)

Read first 16 bytes; match against this prefix set. First
match wins.

| Bytes (hex)          | Mime                          | Notes |
|----------------------|-------------------------------|-------|
| `7f 45 4c 46`        | `application/x-executable`    | ELF. |
| `89 50 4e 47`        | `image/png`                   | PNG. |
| `ff d8 ff`           | `image/jpeg`                  | JPEG/JFIF/Exif. |
| `47 49 46 38`        | `image/gif`                   | GIF87a / GIF89a (both start `GIF8`). |
| `50 4b 03 04`        | `application/zip`             | Also covers JAR / DOCX / ODT containers — out-of-scope to distinguish. |
| `50 4b 05 06`        | `application/zip`             | Empty ZIP. |
| `1f 8b`              | `application/gzip`            | gzip stream. |
| `42 5a 68`           | `application/x-bzip2`         | `BZh`. |
| `fd 37 7a 58 5a 00`  | `application/x-xz`            | `\xfd7zXZ\0`. |
| `37 7a bc af 27 1c`  | `application/x-7z-compressed` | `7z…`. |
| `25 50 44 46 2d`     | `application/pdf`             | `%PDF-`. |
| `23 21`              | `application/x-shellscript`   | `#!` shebang. |

Roadmap acceptance check: `application/x-executable` matches
rule (3) for mode-bit-set OR magic (ELF). `text/markdown` is
extension `.md` (rule 2). `application/x-cyrius` is extension
`.cyr` (rule 2). All three pass.

### `mime/default.cyml` schema

Mirrors `icons/default.cyml`'s split-by-source structure:

```cyml
[filenames]
# Exact-match (case-sensitive) before the extension lookup.
Makefile = "text/x-makefile"
Dockerfile = "text/x-dockerfile"

[extensions]
# Lowercased extension after the last `.`.
cyr = "application/x-cyrius"
md = "text/markdown"
…

[magic_bytes]
# Reserved table; v1.0 compile-bakes the magic-byte set in
# src/mime.cyr the same way [filenames]/[extensions] are
# baked. Documented here so runtime-CYML in v1.1 has a
# stable schema target.
```

### Compile-baked vs runtime CYML parse

Same call as ADR 0002 for icons: `mime/default.cyml` is the
spec; `src/mime.cyr` is the implementation. Edit both when
adding a mapping. Runtime CYML loading is a v1.1 candidate
when the cost-benefit changes.

### Column placement

`--mime` shows the mime type as a **variable-width** column.
That breaks the column-fit math used by short / multi-column /
tree layouts (which assume fixed per-cell prefix width).

Decision: `--mime` shows the column **only under `-l`**. Without
`-l`, the flag is parsed but the column doesn't appear (no
error, no silent corruption of column layout). Documented in
`--help` once we ship `--help` (M10 work).

Future: a fixed-width truncated-with-ellipsis variant for short
formats is feasible (`text/markdown   ` padded to 16 cells)
but adds complexity for a niche use case. Defer to post-v1.

### Cost ceiling

For a listing of N entries, `--mime` costs:
- N stats (already paid by other decorations — compute_decor
  reuses the same lstat pass).
- For non-regular files: 0 opens. Just a mode-bit dispatch.
- For regular files with known extension: 0 opens.
- For regular files without known extension AND not executable:
  1 open + 1 read(16) + 1 close per entry.

Worst case (a directory full of extensionless non-executable
files) is N opens. Acceptable trade for the opt-in flag.

## Alternatives considered

- **Magic-first per roadmap literal**. Rejected per cost
  ceiling above.
- **xdg-mime / `/usr/share/mime/` parse**. Would couple
  darshini to freedesktop.org's shared-mime-info database
  (XML, ~100KB+). Out of scope; darshini ships its own
  compile-baked set.
- **Full libmagic equivalent**. Too much code for v1.0.
  The set in §"Magic-bytes set" covers the 90% case.
- **Per-mime color override** (e.g. text/* in gray,
  image/* in pink). Out of scope; ADR 0001 stays the color
  contract.
- **Variable-width column under short formats** (padded with
  ellipsis to fixed width). Deferred per "Column placement"
  above.

## Consequences

- `darshini -l --mime` adds an N-stat-already-paid + up-to-N-
  opens-for-extensionless-files cost per listing. Most
  listings see 0 extra opens.
- `darshini --mime` (without `-l`) is a no-op. Document in
  `--help`.
- Two files to keep in sync (same shape as ADR 0002):
  `mime/default.cyml` (spec) and `src/mime.cyr`
  (implementation). Contributing docs at M8 release call
  this out.
- The `application/zip` mime covers JAR, DOCX, ODT, etc. —
  containers that start with the same PK header. Acceptable
  loss of precision for v1.0; deeper inspection would
  require unzipping which is out of scope.

## References

- [roadmap.md M8](../development/roadmap.md) — "Mime-type recognition (v0.9.0)"
- [ADR 0001 color scheme](0001-color-scheme.md), [ADR 0002 icon format](0002-icon-format.md) — same compile-baked-mapping pattern
- [IANA mime registry](https://www.iana.org/assignments/media-types/media-types.xhtml) — canonical mime names
- [file(1) source magic db](https://github.com/file/file/blob/master/magic/Magdir) — reference for the magic-byte set

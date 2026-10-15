#!/usr/bin/env python3
# gen-width-table.py — regenerate src/width_table.cyr (v1.6.0).
#
# The terminal cell width of a code point, as wcwidth(3) and the
# `unicode-width` crate define it: 2 for East Asian Wide / Fullwidth
# (EastAsianWidth W, F — CJK, Hangul syllables, fullwidth forms, most
# emoji), 0 for combining and format characters (General_Category Mn, Me,
# Cf, except U+00AD SOFT HYPHEN, which terminals draw) plus the Hangul
# medial / final jamo U+1160..U+11FF and U+200B ZERO WIDTH SPACE, 1 for
# everything else. Only the 0 and 2 ranges are stored.
#
# Source: Python's unicodedata (the Unicode version is printed into the
# output). Not run by CI — a CI runner's Python may carry a different
# Unicode version; regenerate deliberately when moving to a new one:
#   python3 -I tests/gen-width-table.py > src/width_table.cyr
import sys
import unicodedata as u


def width(cp):
    if cp == 0xAD:
        return 1
    if 0x1160 <= cp <= 0x11FF or cp == 0x200B:
        return 0
    c = chr(cp)
    if u.category(c) in ('Mn', 'Me', 'Cf'):
        return 0
    if u.east_asian_width(c) in ('W', 'F'):
        return 2
    return 1


ranges = []
for cp in range(0x80, 0x110000):
    if 0xD800 <= cp <= 0xDFFF:
        continue
    w = width(cp)
    if w == 1:
        continue
    if ranges and ranges[-1][1] == cp - 1 and ranges[-1][2] == w:
        ranges[-1][1] = cp
    else:
        ranges.append([cp, cp, w])

PER = 7                       # records per literal: 7 * 13 = 91 bytes
recs = ['%06X%06X%d' % (lo, hi, w) for lo, hi, w in ranges]
out = sys.stdout
out.write('''# darshini — terminal cell widths (v1.6.0). GENERATED — do not edit.
#
# Regenerate: python3 -I tests/gen-width-table.py > src/width_table.cyr
# Unicode %s (Python %s unicodedata). %d ranges: %d wide (2 cells),
# %d zero-width. Every other code point is 1 cell. See width.cyr.
#
# Record i is 13 hex digits "LLLLLLHHHHHHW" — first code point, last code
# point, width — at offset (i %% %d) * 13 of literal i / %d. Records are
# sorted and disjoint, so width.cyr bisects them in place.

var WT_COUNT = %d;
var WT_PER = %d;
var _wt_chunks = 0;

fn _wt_table(): i64 {
    if (_wt_chunks != 0) { return _wt_chunks; }
    var t = vec_new();
''' % (u.unidata_version, sys.version.split()[0], len(ranges),
       sum(1 for r in ranges if r[2] == 2), sum(1 for r in ranges if r[2] == 0),
       PER, PER, len(ranges), PER))
for i in range(0, len(recs), PER):
    out.write('    vec_push(t, "%s");\n' % ''.join(recs[i:i + PER]))
out.write('''    _wt_chunks = t;
    return t;
}
''')

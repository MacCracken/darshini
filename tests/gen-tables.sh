#!/bin/sh
# gen-tables.sh — write the lookup tables darshini compiles in from the
# CYML data files (v1.7.0): icons/default.cyml → src/icons_table.cyr and
# mime/default.cyml → src/mime_table.cyr. The CYML is the source of
# truth; the .cyr files are generated and committed, so adding an icon is
# a CYML edit plus a regenerate, with no runtime parsing (ADR 0002 /
# ADR 0003). CI regenerates both and fails on any difference.
#
# Each table becomes one function that walks the entries in file order
# and returns the mapped string, or 0 when none matches. The type
# overrides, the fallbacks and the [magic_bytes] signatures are code,
# not tables, and stay in src/icons.cyr / src/mime.cyr.
#
# A file the generator cannot represent exactly is refused (exit 1)
# rather than escaped: a key outside [A-Za-z0-9._+-] (extensions also
# lowercase, since the lookup lowercases), an empty value, a value
# holding a backslash (an escape in a Cyrius string), anything after a
# value but a comment, a duplicate key, or entries in a table no lookup
# reads.
#
# Usage (from the repository root):
#   sh tests/gen-tables.sh icons > src/icons_table.cyr
#   sh tests/gen-tables.sh mime  > src/mime_table.cyr
set -eu
export LC_ALL=C

case "${1:-}" in
    icons) src=icons/default.cyml; pfx=_icons_tbl; out=src/icons_table.cyr
           tables="filenames filename_prefixes extensions" ;;
    mime)  src=mime/default.cyml;  pfx=_mime_tbl;  out=src/mime_table.cyr
           tables="filenames extensions" ;;
    *)     echo "usage: tests/gen-tables.sh icons|mime" >&2; exit 2 ;;
esac

# POSIX awk only (CI runs mawk): no gensub, no character classes.
awk -v src="$src" -v pfx="$pfx" -v out="$out" -v kind="$1" -v tables="$tables" '
function fail(msg) {
    printf "gen-tables: %s:%d: %s\n", src, NR, msg > "/dev/stderr"
    bad = 1
}
function trim(s) {
    sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s)
    return s
}
BEGIN {
    nt = split(tables, tlist, " ")
    for (t = 1; t <= nt; t++) { wanted[tlist[t]] = 1; count[tlist[t]] = 0 }
    sec = ""
}
/^[ \t]*#/ || /^[ \t\r]*$/ { next }
/^[ \t]*\[/ {
    sec = trim($0); gsub(/[\[\]]/, "", sec)
    next
}
{
    eq = index($0, "=")
    if (eq == 0) { fail("not a key = \"value\" line"); next }
    if (sec == "") { fail("entry before any [table]"); next }
    if (!(sec in wanted)) { fail("entry in [" sec "], which no lookup reads"); next }
    key = trim(substr($0, 1, eq - 1))
    if (key ~ /^".*"$/) key = substr(key, 2, length(key) - 2)    # TOML quoted key ("7z")
    keyre = "^[A-Za-z0-9._+-]+$"
    if (sec == "extensions") keyre = "^[a-z0-9._+-]+$"
    if (key !~ keyre) { fail("key \"" key "\" is not representable in [" sec "]"); next }
    rest = trim(substr($0, eq + 1))
    if (substr(rest, 1, 1) != "\"") { fail("value is not a quoted string"); next }
    rest = substr(rest, 2)
    close_q = index(rest, "\"")
    if (close_q == 0) { fail("unterminated value"); next }
    val = substr(rest, 1, close_q - 1)
    after = trim(substr(rest, close_q + 1))
    if (after != "" && substr(after, 1, 1) != "#") { fail("text after the value"); next }
    if (val == "") { fail("empty value for \"" key "\""); next }
    if (index(val, "\\") > 0) { fail("backslash in the value for \"" key "\""); next }
    if ((sec, key) in seen) { fail("duplicate key \"" key "\" in [" sec "]"); next }
    seen[sec, key] = 1
    n = ++count[sec]
    keys[sec, n] = key
    vals[sec, n] = val
}
function emit(sec, fname, arg, call, doc,    i, n, w, c, line) {
    n = count[sec]
    print ""
    print "# [" sec "]: " doc
    print "fn " pfx "_" fname "(" arg "): i64 {"
    if (arg == "ext") print "    if (ext == 0) { return 0; }"
    w = 0
    for (i = 1; i <= n; i++) {
        c = call "(" arg ", \"" keys[sec, i] "\") == 1)"
        if (length(c) > w) w = length(c)
    }
    for (i = 1; i <= n; i++) {
        c = call "(" arg ", \"" keys[sec, i] "\") == 1)"
        line = sprintf("    if (%-" w "s { return \"%s\"; }", c, vals[sec, i])
        if (length(line) > 120) {
            print "    if (" c " {"
            print "        return \"" vals[sec, i] "\";"
            print "    }"
        } else {
            print line
        }
    }
    print "    return 0;"
    print "}"
}
END {
    if (bad) exit 1
    print "# GENERATED from " src " by tests/gen-tables.sh — do not edit."
    print "# After editing the CYML, regenerate:"
    print "#   sh tests/gen-tables.sh " kind " > " out
    print "# CI regenerates this file and fails on any difference (v1.7.0)."
    print "# Each function walks one table in file order and returns the mapped"
    print "# string, or 0 when no entry matches."
    emit("filenames", "filename", "name", "_icons_eq_cstr", "exact, case-sensitive basename.")
    if ("filename_prefixes" in wanted)
        emit("filename_prefixes", "prefix", "name", "_icons_starts_with",
             "case-sensitive prefix of the basename, first in file order.")
    emit("extensions", "ext", "ext", "_icons_ext_eq",
         "the lowercased text after the last \".\" (0 when there is none).")
}
' "$src"

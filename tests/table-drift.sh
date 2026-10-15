#!/bin/sh
# table-drift.sh — the CYML data files vs the tables compiled into src/.
#
# ADR 0002 / 0003: icons/default.cyml and mime/default.cyml are the
# human-readable source of truth, and src/icons.cyr / src/mime.cyr
# compile-bake the same mappings. Nothing tied the two together, and
# v1.4.1's audit found the first drift (`xlsx`: in the CYML since M8,
# never in the compiled table). This compares them entry by entry —
# filenames, filename prefixes, extensions, with their glyph / mime —
# and exits 1 on any difference. The [magic_bytes] signatures are code
# (nested byte compares), not a table; they stay a review item.
#
# Usage: tests/table-drift.sh   (from the repository root)
set -eu
export LC_ALL=C

# kind<TAB>key<TAB>value lines from a CYML file, skipping [magic_bytes].
from_cyml() {
    # POSIX awk only (CI runs mawk): no capture groups, no char classes.
    awk '
        /^[ \t]*#/ || /^[ \t]*$/ { next }
        /^\[/ {
            sec = $0; gsub(/[ \t]/, "", sec); gsub(/\[/, "", sec); gsub(/\]/, "", sec)
            kind = ""
            if (sec == "filenames") kind = "filename"
            if (sec == "filename_prefixes") kind = "prefix"
            if (sec == "extensions") kind = "ext"
            next
        }
        kind != "" && index($0, "=") > 0 {
            eq = index($0, "=")
            key = substr($0, 1, eq - 1); gsub(/[ \t]/, "", key); gsub(/"/, "", key)
            n = split(substr($0, eq + 1), q, "\"")      # a TOML key may be quoted ("7z")
            if (n >= 3) printf "%s\t%s\t%s\n", kind, key, q[2]
        }
    ' "$1" | sort
}

# The same lines from a src table: each _icons_eq_cstr / _starts_with /
# _ext_eq literal paired with the next `return "..."` (same line or the
# next ones — a long mime arm wraps). Returns with no pending key (type
# overrides, inode / magic results, fallbacks) are not table entries.
from_src() {
    grep -oE '_icons_(eq_cstr|starts_with|ext_eq)\([a-z_]+, "[^"]*"\)|return "[^"]*";' "$1" | awk '
        /^_icons_/ {
            kind = "ext"
            if (index($0, "_icons_eq_cstr") == 1) kind = "filename"
            if (index($0, "_icons_starts_with") == 1) kind = "prefix"
            split($0, q, "\""); key = q[2]; pending = 1
            next
        }
        pending == 1 {
            split($0, q, "\""); printf "%s\t%s\t%s\n", kind, key, q[2]; pending = 0
        }
    ' | sort
}

fail=0
check() {   # $1 = cyml, $2 = src
    a=$(mktemp); b=$(mktemp)
    from_cyml "$1" > "$a"
    from_src "$2" > "$b"
    if diff -u "$a" "$b" > /dev/null; then
        echo "table-drift: $1 == $2 ($(wc -l < "$a") entries)"
    else
        echo "table-drift: $1 and $2 disagree (- only in the CYML, + only in src):"
        diff -u "$a" "$b" | sed -n '3,$p' | grep -E '^[-+]' || true
        fail=1
    fi
    rm -f "$a" "$b"
}

check icons/default.cyml src/icons.cyr
check mime/default.cyml src/mime.cyr
exit $fail

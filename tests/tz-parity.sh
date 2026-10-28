#!/bin/sh
# tz-parity.sh — `darshini -l --local-time` against date(1) (v1.6.0).
#
# Files are given mtimes at random instants across 1901..2242 (the range
# every common filesystem stores) plus every DST transition zdump(8)
# reports for a set of zones (and one second either side); then, for each
# zone — awkward ones on purpose: 30- and 45-minute offsets, southern-
# hemisphere and negative DST, Casablanca's Ramadan shifts, Samoa's
# skipped day, POSIX rule strings in every date form, TZ given as a
# ":name", an absolute path, empty, and unset — each file's mtime column
# must equal `date -d @EPOCH '+%Y-%m-%d %H:%M'` under the same TZ.
#
# Usage (from the repository root, after `cyrius build`):
#   tests/tz-parity.sh [random-count]      (default 300)
set -eu
export LC_ALL=C
B="$PWD/build/darshini"
[ -x "$B" ] || { echo "tz-parity: build/darshini not built" >&2; exit 1; }
N="${1:-300}"
# The oracle is glibc's localtime as GNU date reports it: darshini copies
# glibc's rules on purpose (state.md). Not any date(1) — Ubuntu 26.04's is
# uutils (Rust), which applies POSIX rules before 1970 and reads a
# DST name with no rule (XST8XDT) as UTC. There GNU's is `gnudate`
# (package gnu-coreutils). No GNU date is a failure, not a skip.
DATE=
for d in date gnudate; do
    if command -v "$d" > /dev/null 2>&1 && "$d" --version 2> /dev/null | head -1 | grep -q 'GNU coreutils'; then
        DATE="$d"
        break
    fi
done
[ -n "$DATE" ] || { echo "tz-parity: needs GNU date (glibc's TZ rules; Ubuntu 26.04: gnu-coreutils)" >&2; exit 1; }
ZI="${TZDIR:-/usr/share/zoneinfo}"
[ -f "$ZI/America/New_York" ] || { echo "tz-parity: skip (no zoneinfo at $ZI)"; exit 0; }
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir "$T/f"

# Epochs: random, deterministic seed, -2^31 .. 2^33.
awk -v n="$N" 'BEGIN { srand(1701); for (i = 0; i < n; i++)
    printf "%d\n", int(-2147483648 + rand() * (8589934592 + 2147483648)) }' > "$T/epochs"
printf '%s\n' 0 1 -1 86399 86400 -86400 -2147483648 2147483647 8589934591 1700000000 >> "$T/epochs"
# Transitions (and +-1 s) for a few zones, from zdump if present. Its
# lines read "ZONE  Sun Mar 10 06:59:59 2024 UT = ... gmtoff=...".
if command -v zdump > /dev/null 2>&1; then
    for z in America/New_York Europe/Dublin Australia/Lord_Howe Africa/Casablanca Pacific/Apia; do
        zdump -v -c 1902,2240 "$z" 2> /dev/null \
            | awk '$7 == "UT" && $6 ~ /^[0-9]+$/ && $6 >= 1902 && $6 <= 2240 { print $3, $4, $6, $5, "UTC" }' \
            > "$T/zd" || true
        if [ -s "$T/zd" ]; then
            "$DATE" -u -f "$T/zd" '+%s' 2> /dev/null | awk '{ print $1 - 1; print $1; print $1 + 1 }' >> "$T/epochs" || true
        fi
    done
fi
sort -un "$T/epochs" > "$T/e"
count=0
while read -r e; do
    touch -d "@$e" "$T/f/e_$e" 2> /dev/null && count=$((count + 1))
done < "$T/e"
ls "$T/f" | sed 's/^e_//' | sort -n > "$T/have"
sed 's/^/@/' "$T/have" > "$T/at"

fail=0
check() {   # $1 = label, $2 = TZ value or "-unset-", [$3 = only instants below this epoch]
    if [ "$2" = "-unset-" ]; then
        env -u TZ "$B" -l --local-time "$T/f" > "$T/out"
        env -u TZ "$DATE" -f "$T/at" '+%Y-%m-%d %H:%M' > "$T/want_t"
    else
        TZ="$2" "$B" -l --local-time "$T/f" > "$T/out"
        TZ="$2" "$DATE" -f "$T/at" '+%Y-%m-%d %H:%M' > "$T/want_t"
    fi
    # darshini rows: perms size date time e_EPOCH (sorted by name) -> by epoch
    awk '{ sub(/^e_/, "", $5); print $5, $3 " " $4 }' "$T/out" | sort -n > "$T/got"
    paste -d' ' "$T/have" "$T/want_t" > "$T/want"
    if [ -n "${3:-}" ]; then
        awk -v m="$3" '$1 < m' "$T/got" > "$T/g2" && mv "$T/g2" "$T/got"
        awk -v m="$3" '$1 < m' "$T/want" > "$T/w2" && mv "$T/w2" "$T/want"
    fi
    if cmp -s "$T/want" "$T/got"; then
        echo "tz-parity: ok   $1 ($(wc -l < "$T/want") instants)"
    else
        echo "tz-parity: FAIL $1 (- date, + darshini):"
        diff "$T/want" "$T/got" | head -8
        fail=1
    fi
}

for z in UTC America/New_York America/Los_Angeles America/St_Johns America/Sao_Paulo America/Santiago \
         Europe/London Europe/Dublin Europe/Berlin Europe/Moscow Africa/Casablanca Asia/Kolkata \
         Asia/Kathmandu Asia/Tehran Asia/Tokyo Australia/Sydney Australia/Lord_Howe Pacific/Chatham \
         Pacific/Apia Pacific/Kiritimati Antarctica/Troll; do
    [ -f "$ZI/$z" ] && check "$z" "$z"
done
check ":America/New_York" ":America/New_York"
check "absolute path" "$ZI/Asia/Tokyo"
check "TZ empty (UTC)" ""
check "TZ unset (/etc/localtime)" "-unset-"
check "POSIX EST5EDT,M3.2.0,M11.1.0" "EST5EDT,M3.2.0,M11.1.0"
check "POSIX <+0330>-3:30" "<+0330>-3:30"
check "POSIX AEST-10AEDT,M10.1.0,M4.1.0/3" "AEST-10AEDT,M10.1.0,M4.1.0/3"
check "POSIX IST-1GMT0,M10.5.0,M3.5.0/1 (negative DST)" "IST-1GMT0,M10.5.0,M3.5.0/1"
check "POSIX Jn / n forms" "AAA3BBB,J60/2,300/3"
check "POSIX permanent DST" "EST5EDT4,0/0,J365/25"
# DST without a rule: glibc borrows $TZDIR/posixrules' transition history
# (darshini does the same). Past that file's last explicit transition glibc
# keeps the file's OWN offsets — a glibc defect darshini does not copy — and
# a "slim" posixrules ends its explicit transitions in 2007, so compare
# only instants before 2007-01-01.
check "POSIX DST without a rule (posixrules, < 2007)" "XST8XDT" 1167609600
check "POSIX east, no rule (posixrules, < 2007)" "AAA-3BBB" 1167609600
exit $fail

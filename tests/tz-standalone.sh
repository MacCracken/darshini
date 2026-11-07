#!/bin/sh
# tz-standalone.sh — src/tz.cyr builds and works with no other darshini file (v1.8.2).
#
# commandress pins src/tz.cyr alone as a source dep. darshini compiles that
# file beside everything else, so its own build cannot notice a call to
# walk.cyr or a constant from it creeping in: the break would first show
# in the consumer, against a tag. This does what the consumer does. In a
# scratch directory outside the checkout it builds a tiny program from the
# stdlib modules tz.cyr's header allows and a copy of the file, for each
# target, with and without dead-code elimination, and checks:
#   * lib/ holds no fs, hashmap, args or darshana to lean on;
#   * tz_offset agrees with date(1) for zone names and POSIX strings, after
#     300 tz_init calls under a low `ulimit -n` (a consumer calls it per
#     redraw, so a leaked fd must fail here);
#   * TZ naming a FIFO or a device gives UTC, at once.
#
# agnos and aarch64 run where they can: aarch64 under qemu-aarch64 when it
# is installed, agnos under mirshi when MIRSHI names its binary. mirshi
# gives a child no environment at all, so TZ cannot be set there: the agnos
# run covers a root with no zone database (UTC) and one with an
# /etc/localtime (the unset-TZ path).
#
# Usage (from the repository root):
#   tests/tz-standalone.sh
#   MIRSHI=<path to mirshi> tests/tz-standalone.sh
set -eu
export LC_ALL=C
R="$PWD"
[ -f "$R/src/tz.cyr" ] || { echo "tz-standalone: run from the repository root" >&2; exit 1; }
# GNU's date, for the same reason as tests/tz-parity.sh.
DATE=
for d in date gnudate; do
    if command -v "$d" > /dev/null 2>&1 && "$d" --version 2> /dev/null | head -1 | grep -q 'GNU coreutils'; then
        DATE="$d"
        break
    fi
done
[ -n "$DATE" ] || { echo "tz-standalone: needs GNU date (Ubuntu 26.04: gnu-coreutils)" >&2; exit 1; }
ZI="${TZDIR:-/usr/share/zoneinfo}"
[ -f "$ZI/America/New_York" ] || { echo "tz-standalone: needs zoneinfo at $ZI" >&2; exit 1; }
PIN="$(grep '^cyrius = ' cyrius.cyml | head -1 | sed 's/cyrius = "\(.*\)"/\1/')"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail=0
bad() { echo "tz-standalone: FAIL $1"; fail=1; }

mkdir "$T/p" "$T/p/build"
cp src/tz.cyr "$T/p/tz.cyr"
cat > "$T/p/cyrius.cyml" <<EOF
[package]
name = "tzprobe"
version = "0.0.0"
license = "GPL-3.0-only"
language = "cyrius"
cyrius = "$PIN"

[build]
entry = "probe.cyr"
output = "tzprobe"

[deps]
stdlib = ["string", "fmt", "alloc", "io", "vec", "str", "syscalls", "chrono"]
EOF
cat > "$T/p/probe.cyr" <<'EOF'
include "lib/string.cyr"
include "lib/fmt.cyr"
include "lib/alloc.cyr"
include "lib/io.cyr"
include "lib/vec.cyr"
include "lib/str.cyr"
include "lib/syscalls.cyr"
include "lib/chrono.cyr"
include "tz.cyr"

# "<epoch> <+HHMM>\n", as `date -d @epoch +%z` writes the offset.
fn show(t): i64 {
    var b[64];
    var n = fmt_int_buf(t, &b);
    store8(&b + n, 32);
    n = n + 1;
    var off = tz_offset(t);
    var sign = 43;
    if (off < 0) { sign = 45; off = 0 - off; }
    store8(&b + n, sign);
    var hhmm = (off / 3600) * 100 + (off % 3600) / 60;
    store8(&b + n + 1, 48 + (hhmm / 1000) % 10);
    store8(&b + n + 2, 48 + (hhmm / 100) % 10);
    store8(&b + n + 3, 48 + (hhmm / 10) % 10);
    store8(&b + n + 4, 48 + hhmm % 10);
    store8(&b + n + 5, 10);
    sys_write(1, &b, n + 6);
    return 0;
}

fn main(): i64 {
    alloc_init();
    var i = 0;
    while (i < 300) { tz_init(); i = i + 1; }
    show(clock_epoch_secs());
    show(0);
    show(1700000000);
    show(1720000000);
    show(1710054000 - 1);
    show(1710054000);
    show(4102444800);
    show(4118083200);
    return 0;
}

var r = main();
syscall(SYS_EXIT, r);
EOF
cd "$T/p"
cyrius deps > "$T/deps.log" 2>&1 || { cat "$T/deps.log"; echo "tz-standalone: cyrius deps failed" >&2; exit 1; }
for m in fs hashmap args darshana; do
    [ ! -e "lib/$m.cyr" ] || bad "lib/$m.cyr is there: the build is not standalone"
done

build() {   # $1 = output, rest = build flags
    o="$1"; shift
    if cyrius build "$@" probe.cyr "build/$o" > "$T/build.log" 2>&1; then
        echo "tz-standalone: ok   build $o"
    else
        cat "$T/build.log"
        bad "build $o"
    fi
}
build tzprobe
build tzprobe-dce --dce
build tzprobe-agnos --agnos
build tzprobe-agnos-dce --agnos --dce
build tzprobe-aarch64 --aarch64
[ "$fail" -eq 0 ] || exit 1

# date's offsets for the instants in $T/got, under TZ value $1 or "-unset-".
oracle() {
    while read -r at _; do
        if [ "$1" = "-unset-" ]; then w="$(env -u TZ "$DATE" -d "@$at" +%z)"
        else w="$(TZ="$1" "$DATE" -d "@$at" +%z)"; fi
        printf '%s %s\n' "$at" "$w"
    done < "$T/got"
}
# $1 = runner label, $2 = command, $3 = TZ value or "-unset-"
check() {
    (
        ulimit -n 32
        if [ "$3" = "-unset-" ]; then env -u TZ $2 > "$T/got"
        else TZ="$3" $2 > "$T/got"; fi
    ) || { bad "$1: TZ='$3' exited non-zero"; return 0; }
    oracle "$3" > "$T/want"
    if [ -s "$T/got" ] && cmp -s "$T/got" "$T/want"; then
        echo "tz-standalone: ok   $1: TZ='$3' ($(wc -l < "$T/got") instants)"
    else
        bad "$1: TZ='$3' (- date, + probe):"
        diff "$T/want" "$T/got" | head -6
    fi
}
zones() {
    for tz in UTC America/New_York America/St_Johns Asia/Kathmandu Australia/Lord_Howe \
              Europe/Dublin :Asia/Tokyo "$ZI/Europe/Berlin" "" -unset- \
              'EST5EDT,M3.2.0,M11.1.0' '<+0330>-3:30' 'AEST-10AEDT,M10.1.0,M4.1.0/3'; do
        check "$1" "$2" "$tz"
    done
}
zones native build/tzprobe
zones dce build/tzprobe-dce
if command -v qemu-aarch64 > /dev/null 2>&1; then
    zones aarch64 "qemu-aarch64 build/tzprobe-aarch64"
else
    echo "tz-standalone: skip aarch64 run (no qemu-aarch64)"
fi

# What the consumer must survive: each is UTC, and must return.
mkfifo "$T/fifo"
for tz in "$T/fifo" ":$T/fifo" /dev/zero :/dev/zero /dev/null "$T" /; do
    if TZ="$tz" timeout 5 build/tzprobe > "$T/got"; then
        if [ "$(awk '{ print $2 }' "$T/got" | sort -u)" = "+0000" ]; then
            echo "tz-standalone: ok   TZ='$tz' is UTC"
        else
            bad "TZ='$tz' is not UTC"
        fi
    else
        bad "TZ='$tz' hung or failed (exit $?)"
    fi
done

if [ -n "${MIRSHI:-}" ]; then
    run_agnos() {   # $1 = root, $2 = binary; mirshi talks on stderr
        "$MIRSHI" --root "$1" "$2" 2> /dev/null > "$T/got" || bad "agnos: $2 exited non-zero"
    }
    mkdir -p "$T/r0" "$T/r1/etc"
    for b in tzprobe-agnos tzprobe-agnos-dce; do
        run_agnos "$T/r0" "build/$b"
        if [ "$(awk '{ print $2 }' "$T/got" | sort -u)" = "+0000" ]; then
            echo "tz-standalone: ok   $b: no zone database is UTC"
        else
            bad "$b: no zone database should be UTC"
        fi
        for z in America/New_York Asia/Kathmandu; do
            cp "$ZI/$z" "$T/r1/etc/localtime"
            run_agnos "$T/r1" "build/$b"
            oracle "$z" > "$T/want"
            if [ -s "$T/got" ] && cmp -s "$T/got" "$T/want"; then
                echo "tz-standalone: ok   $b: /etc/localtime = $z"
            else
                bad "$b: /etc/localtime = $z (- date, + probe):"
                diff "$T/want" "$T/got" | head -6
            fi
        done
    done
else
    echo "tz-standalone: skip agnos run (set MIRSHI to the mirshi binary)"
fi

cd "$R"
[ "$fail" -eq 0 ] && echo "tz-standalone: PASS"
exit "$fail"

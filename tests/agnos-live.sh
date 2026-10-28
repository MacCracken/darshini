#!/bin/sh
# agnos-live.sh — darshini's agnos build on a real agnos kernel, in QEMU (v1.8.0).
#
# mirshi 1.11.3 has no lstat#102, so CI's agnos runs exercise only the
# stat#33 fallback. This boots agnos itself: it builds tests/agnos_live.cyr
# and darshini with `--agnos`, seeds them (the driver as /bin/agnsh, init)
# with a fixture on an ext2 root next to an agnos kernel and gnoboot, boots
# the image in QEMU, and scores the driver's output from the serial log
# (agnos writes the console to COM1). The image recipe is darshana's
# scripts/agnos-live.sh, which is agnos's own (scripts/harness/tty-test.py).
#
# Not a CI gate: it needs an agnos kernel build, which a runner does not
# have. A release step, like the Raspberry Pi run (state.md).
#
# Inputs, read and never modified:
#   AGNOS_KERNEL  default ${SIBLINGS_ROOT:-..}/agnos/build/agnos (>= 1.56.53, lstat#102)
#   GNOBOOT_EFI   default ${SIBLINGS_ROOT:-..}/gnoboot/build/BOOTX64.EFI
#   OVMF          the edk2 / OVMF firmware the distribution installs
#   LIVE_REF_BIN  optional: an older darshini agnos build (before v1.8.1),
#                 seeded as /bin/darshini-ref and run on the console, where it
#                 must NOT be decorated — the contrast for the console checks
# Env: LIVE_TIMEOUT seconds to wait for one boot (default 120);
#      LIVE_TRIES boots before giving up as VOID (default 4);
#      SMOKE_KVM=0 to use TCG even when /dev/kvm is writable.
# Writes only build/agnos-live/ (the image, the binaries, serial.log).
# Exit: 0 every check passed · 1 a check failed · 2 VOID (an input is
# missing, or the boot never reached the driver: nothing was measured).

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIB="${SIBLINGS_ROOT:-$ROOT/..}"
KERNEL="${AGNOS_KERNEL:-$SIB/agnos/build/agnos}"
EFI="${GNOBOOT_EFI:-$SIB/gnoboot/build/BOOTX64.EFI}"
TIMEOUT="${LIVE_TIMEOUT:-120}"
MIN_AGNOS="1.56.53"
# The driver's assertion total, pinned: a count that moves by itself is a
# check that stopped running. (LIVE_REF_BIN adds a console segment, below.)
EXPECT_LIVE=30

void() { echo "agnos-live: VOID — $1 (nothing was measured)" >&2; exit 2; }
fail() { echo "agnos-live: FAIL — $1" >&2; exit 1; }

[ -f "$KERNEL" ] || void "no agnos kernel at $KERNEL (set AGNOS_KERNEL)"
[ -f "$EFI" ] || void "no gnoboot at $EFI (set GNOBOOT_EFI)"
[ -z "${LIVE_REF_BIN:-}" ] || [ -f "$LIVE_REF_BIN" ] || void "no reference build at $LIVE_REF_BIN"
for t in cyrius qemu-system-x86_64 parted sgdisk mformat mmd mcopy mkfs.ext2 strings python3; do
    command -v "$t" >/dev/null 2>&1 || void "$t is not installed"
done
OVMF_CODE=""; OVMF_VARS=""
for c in /usr/share/edk2/x64/OVMF_CODE.4m.fd /usr/share/edk2/x64/OVMF_CODE.fd \
         /usr/share/OVMF/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE_4M.fd; do
    [ -f "$c" ] && { OVMF_CODE="$c"; break; }
done
for c in /usr/share/edk2/x64/OVMF_VARS.4m.fd /usr/share/edk2/x64/OVMF_VARS.fd \
         /usr/share/OVMF/OVMF_VARS.fd /usr/share/OVMF/OVMF_VARS_4M.fd; do
    [ -f "$c" ] && { OVMF_VARS="$c"; break; }
done
[ -n "$OVMF_CODE" ] && [ -n "$OVMF_VARS" ] || void "no OVMF firmware found"

KVER=$(strings "$KERNEL" | grep -m1 -oE 'AGNOS kernel v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/.* v//')
[ -n "$KVER" ] || void "cannot read the kernel version from $KERNEL"
[ "$(printf '%s\n%s\n' "$MIN_AGNOS" "$KVER" | sort -V | head -1)" = "$MIN_AGNOS" ] \
    || void "agnos $KVER predates $MIN_AGNOS, which added lstat#102"
echo "agnos-live: kernel v$KVER ($KERNEL)"

WORK="$ROOT/build/agnos-live"
rm -rf "$WORK"
mkdir -p "$WORK/seed/bin" "$WORK/seed/out"
cd "$ROOT" || void "cannot enter $ROOT"
cyrius build --agnos tests/agnos_live.cyr "$WORK/seed/bin/agnsh" > "$WORK/build.log" 2>&1 \
    || fail "the --agnos driver build failed (see $WORK/build.log)"
cyrius build --agnos src/main.cyr "$WORK/seed/bin/darshini" >> "$WORK/build.log" 2>&1 \
    || fail "the --agnos darshini build failed (see $WORK/build.log)"
grep -qiE '[1-9][0-9]* warnings?' "$WORK/build.log" && fail "an --agnos build warned (see $WORK/build.log)"
[ -n "${LIVE_REF_BIN:-}" ] && cp "$LIVE_REF_BIN" "$WORK/seed/bin/darshini-ref"

# The fixture: a file, an executable, a directory with one entry, and links
# to each kind of target — a file, a directory, nothing, each other.
# mkfs.ext2 -d copies them as links, with their modes and mtimes.
python3 -I - "$WORK/seed/fx" <<'EOF' || void "cannot build the fixture"
import os, sys
fx = sys.argv[1]
os.makedirs(os.path.join(fx, "d"))
for name, data, mode in [("f", b"hello\n", 0o644), ("x", b"#!x\n", 0o755),
                         ("README.md", b"# r\n", 0o644), ("d/inner", b"", 0o644)]:
    p = os.path.join(fx, name)
    open(p, "wb").write(data)
    os.chmod(p, mode)
for name, target in [("to_f", "f"), ("to_d", "d"), ("broken", "nowhere"),
                     ("loop_a", "loop_b"), ("loop_b", "loop_a")]:
    os.symlink(target, os.path.join(fx, name))
T = 1700000000
for dp, dns, fns in os.walk(fx, topdown=False):
    for n in dns + fns:
        os.utime(os.path.join(dp, n), (T, T), follow_symlinks=False)
os.utime(fx, (T, T))
EOF

# ESP 1-33 MiB (gnoboot + kernel), ext2 33-100 MiB seeded with the driver.
IMG="$WORK/live.img"
run() { "$@" > /dev/null 2>> "$WORK/image.log" || fail "image step failed: $* (see $WORK/image.log)"; }
run dd if=/dev/zero of="$IMG" bs=1M count=128 status=none
run parted -s "$IMG" mklabel gpt mkpart ESP fat32 1MiB 33MiB set 1 esp on mkpart agnos-fs ext2 33MiB 100MiB
run sgdisk -t 2:8300 "$IMG"
run mformat -i "$IMG@@1048576" -F
run mmd -i "$IMG@@1048576" ::EFI ::EFI/BOOT ::boot
run mcopy -i "$IMG@@1048576" "$EFI" ::EFI/BOOT/BOOTX64.EFI
run mcopy -i "$IMG@@1048576" "$KERNEL" ::boot/agnos
run mkfs.ext2 -F -q -L DARSHINI-LIVE -b 4096 -m 0 \
    -O '^resize_inode,^dir_index,^metadata_csum,^64bit,^uninit_bg' \
    -d "$WORK/seed" -E offset=$((33 * 1048576)) "$IMG" $(((67 * 1048576) / 4096))
ACCEL="-cpu max"
if [ -w /dev/kvm ] && [ "${SMOKE_KVM:-1}" = "1" ]; then ACCEL="-enable-kvm -cpu host"; fi
SER="$WORK/serial.log"

# One boot. Echoes END (the driver finished), HUNG (it started and never
# finished: a failure), or VOID (firmware never handed off to agnos, or
# nothing arrived in time: retried, never scored).
boot() {
    cp "$OVMF_VARS" "$WORK/vars.fd" && chmod +w "$WORK/vars.fd"
    : > "$SER"
    # shellcheck disable=SC2086
    qemu-system-x86_64 -machine q35 -m 512M $ACCEL -smp 1 \
        -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
        -drive if=pflash,format=raw,file="$WORK/vars.fd" \
        -drive file="$IMG",format=raw,if=none,id=disk0 -device nvme,drive=disk0,serial=DARSHINI-LIVE \
        -serial file:"$SER" -display none -no-reboot > "$WORK/qemu.log" 2>&1 &
    QPID=$!
    trap 'kill "$QPID" 2>/dev/null; wait "$QPID" 2>/dev/null' EXIT INT TERM
    _r=VOID
    _t=0
    while [ "$_t" -lt "$TIMEOUT" ]; do
        if grep -q 'DARSHINI-LIVE-END' "$SER"; then _r=END; break; fi
        if grep -qE 'BootManagerMenuApp|Please select boot device|gnoboot: fail @' "$SER"; then break; fi
        kill -0 "$QPID" 2>/dev/null || break
        sleep 1
        _t=$((_t + 1))
    done
    kill "$QPID" 2>/dev/null; wait "$QPID" 2>/dev/null
    trap - EXIT INT TERM
    if [ "$_r" = VOID ] && grep -q 'DARSHINI-LIVE-BEGIN' "$SER"; then _r=HUNG; fi
    echo "$_r"
}

TRIES="${LIVE_TRIES:-4}"
n=1
while :; do
    r=$(boot)
    [ "$r" = VOID ] || break
    echo "agnos-live: boot $n never reached the driver (VOID), retrying" >&2
    [ "$n" -lt "$TRIES" ] || void "no boot of $TRIES reached the driver (last serial log: $SER)"
    n=$((n + 1))
done
[ "$r" = END ] || fail "the driver started but never finished within ${TIMEOUT}s (serial log: $SER)"

OUT=$(tr -d '\r' < "$SER" | awk '/DARSHINI-LIVE-BEGIN/ { on = 1 } on { print } /DARSHINI-LIVE-END/ { exit }')
printf '%s\n' "$OUT"
printf '%s\n' "$OUT" | grep -q "^$EXPECT_LIVE passed, 0 failed ($EXPECT_LIVE total)\$" \
    || fail "expected $EXPECT_LIVE passed, 0 failed ($EXPECT_LIVE total)"

# The console segments: darshini wrote to a terminal there, and since
# v1.8.1 decorates it where darshana's tty_isatty is per fd (agnos >=
# 1.57.13, darshana 1.6.0's tty_isatty_is_per_fd). Each must show what a
# Linux terminal shows; the redirected runs above stayed plain.
seg() { printf '%s\n' "$OUT" | awk -v b="DARSHINI-CONSOLE-$1-BEGIN" -v e="DARSHINI-CONSOLE-$1-END" \
    '$0 == b { on = 1; next } $0 == e { exit } on { print }'; }
has_esc() { printf '%s' "$1" | od -An -tx1 | grep ' 1b' > /dev/null; }
LONG=$(seg LONG); GRID=$(seg GRID); PLAIN=$(seg PLAIN)
[ -n "$LONG" ] && [ -n "$GRID" ] && [ -n "$PLAIN" ] || fail "a console segment is missing"
has_esc "$LONG" || fail "console -l: not decorated (no escape)"
printf '%s\n' "$LONG" | grep -q '^lrwx.*to_d.* -> ' || fail "console -l: to_d is not an l row with its target"
printf '%s\n' "$LONG" | grep -q "$(printf 'broken.* -> \033\\[31mnowhere')" || fail "console -l: the broken link's target is not red"
printf '%s\n' "$LONG" | grep -q "$(printf 'to_d.* -> \033\\[34md')" || fail "console -l: the directory target is not blue"
has_esc "$GRID" || fail "console grid: not decorated"
[ "$(printf '%s\n' "$GRID" | grep -c .)" -lt 9 ] || fail "console grid: one entry per line (no grid)"
if has_esc "$PLAIN"; then fail "console -l --no-color --no-icons: an escape appeared"; fi
printf '%s\n' "$PLAIN" | grep -q '^lrwx.* to_d -> d$' || fail "console -l --no-color: no plain link target"
note=""
if [ -n "${LIVE_REF_BIN:-}" ]; then
    REF=$(seg REF)
    [ -n "$REF" ] || fail "the reference build's console segment is missing"
    if has_esc "$REF"; then fail "the reference build decorated the console: the contrast is gone"; fi
    note=", the reference build undecorated"
fi
echo "agnos-live: PASS ($EXPECT_LIVE assertions + 3 decorated console listings$note, on agnos v$KVER)"

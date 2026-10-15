#!/bin/sh
# parity.sh — two darshini builds must produce identical bytes and exit
# codes across a mode matrix, on a pipe and under a PTY.
#
# Used by CI for the DCE release build vs the normal build, and for the
# aarch64 build (under qemu-aarch64) vs x86_64. Run from the repository
# root, so the listing is the checkout itself.
#
# Usage: tests/parity.sh "<reference command>" "<candidate command>"
#   e.g. tests/parity.sh ./build/darshini "qemu-aarch64 ./build/darshini-aarch64"
set -u

ref="$1"
cand="$2"
fail=0
n=0
for mode in "" "-1" "-l" "-lh" "-lF" "-F" "-T" "-T -l" "-T --git" "-l --git" "--git" \
            "-l --mime" "-d src" "-dF src" "src docs" "-l README.md" "-F -- src" \
            "--help" "--version" "--bogus" "/nonexistent"; do
    $ref $mode > /tmp/parity_ref 2>&1; rr=$?
    $cand $mode > /tmp/parity_cand 2>&1; rc=$?
    script -qec "$ref $mode" /dev/null > /tmp/parity_ref_tty 2>&1
    script -qec "$cand $mode" /dev/null > /tmp/parity_cand_tty 2>&1
    n=$((n + 1))
    if [ "$rr" != "$rc" ]; then
        echo "parity: '$mode' exit $rr vs $rc"; fail=1
    elif ! cmp -s /tmp/parity_ref /tmp/parity_cand; then
        echo "parity: '$mode' differs on a pipe"; diff /tmp/parity_ref /tmp/parity_cand | head -5; fail=1
    elif ! cmp -s /tmp/parity_ref_tty /tmp/parity_cand_tty; then
        echo "parity: '$mode' differs under a PTY"; fail=1
    fi
done
[ $fail -eq 0 ] && echo "parity: $n modes identical (pipe + PTY): $cand == $ref"
exit $fail

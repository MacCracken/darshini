#!/bin/sh
# git-parity.sh — darshini's --git column against real git (ADR 0005).
#
# Builds repositories that exercise every ignore rule darshini
# reimplements, then requires:
#   1. the set of paths darshini marks '!' to equal `git check-ignore`'s,
#      in every directory (nested .gitignore files, negation, anchoring,
#      classes, `**`, escapes, trailing spaces, CRLF, an excluded
#      directory's contents, info/exclude, core.excludesFile);
#   2. `.git` and everything in it to carry no status;
#   3. a submodule to read '.' when its HEAD is the recorded commit and
#      'M' after it moves, and its own files to be listed through its
#      `gitdir:` file;
#   4. a linked worktree to work, with the common dir's info/exclude;
#   5. (when passwordless sudo is available, as on CI) a repository owned
#      by another user to get no column until safe.directory lists it.
# HOME / XDG_CONFIG_HOME point into a temp dir and GIT_CONFIG_NOSYSTEM is
# set, for git and darshini alike, so the user's own config can't leak in.
#
# Usage (from the repository root, after `cyrius build`):
#   tests/git-parity.sh
set -eu
export LC_ALL=C
B="$PWD/build/darshini"
[ -x "$B" ] || { echo "git-parity: build/darshini not built" >&2; exit 1; }
T="$(mktemp -d)"
T="$(cd "$T" && pwd -P)"
cleanup() {
    chmod -R u+rwX "$T" 2>/dev/null || true
    if [ -e "$T/owned" ]; then sudo -n rm -rf "$T/owned" 2>/dev/null || true; fi
    rm -rf "$T"
}
trap cleanup EXIT
export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$XDG_CONFIG_HOME/git"
G="git -c user.email=ci@ci -c user.name=ci -c init.defaultBranch=main -c protocol.file.allow=always"
fail=0
ok() { echo "git-parity: ok   $1"; }
bad() { echo "git-parity: FAIL $1"; fail=1; }

# darshini's '!' set for every directory of repo $1 (excluding .git).
darshini_ignored() {
    (
        cd "$1"
        find . -path ./.git -prune -o -type d -print | sed 's|^\./||; s|^\.$||' | while IFS= read -r d; do
            "$B" --git -1 --no-color --no-icons "${d:-.}" | while IFS= read -r line; do
                case "$line" in
                    "! "*) n="${line#??}"; if [ -n "$d" ]; then echo "$d/$n"; else echo "$n"; fi ;;
                esac
            done
        done | sort
    )
}

git_ignored() {
    (
        cd "$1"
        find . -path ./.git -prune -o -print | sed 's|^\./||' | grep -v '^\.$' | sort \
            | git check-ignore --stdin | sort || true
    )
}

compare_ignores() {   # $1 = label, $2 = repo
    darshini_ignored "$2" > "$T/got"
    git_ignored "$2" > "$T/want"
    n=$(wc -l < "$T/want")
    if diff -u "$T/want" "$T/got" > "$T/diff"; then
        ok "$1: '!' set == git check-ignore ($n ignored paths)"
    else
        bad "$1: '!' set differs from git check-ignore (- git only, + darshini only):"
        sed -n '3,$p' "$T/diff" | grep -E '^[-+]' | head -20
    fi
}

# ------------------------------------------------------------ 1. rules
R="$T/repo"
mkdir -p "$R"
$G init -q "$R"
cd "$R"
printf 'tracked\n' > README
mkdir -p src build sub/gen sub/x sub/nested/deep gen doc/a/b logs/important crlf/only
printf 'int x;\n' > src/main.c
printf 'k\n' > build/keep.txt
$G add README src/main.c
$G add -f build/keep.txt
$G commit -qm init
cat > .gitignore <<'EOF'
# comment
*.log
!keep.log
/TODO
build/
*.py[cod]
**/gen/
doc/**/x.md
\#hash
sp\
trail
 lead
logs/**
!logs/important/
foo?.txt
[Mm]akefile.bak
a*b
EOF
printf '!a.log\nlocal.txt\n/anchored.txt\nnested/deep/*.tmp\n' > sub/.gitignore
printf '!out.o\n' > build/.gitignore
printf '*.swp\r\nonly/\r\n' > crlf/.gitignore
mkdir -p .git/info
printf '*.tmp\n!root.tmp\n' > .git/info/exclude
printf '*.orig\n.DS_Store\n' > "$XDG_CONFIG_HOME/git/ignore"
for f in a.log keep.log TODO src/TODO build/out.o build/keep.log x.pyc x.py sub/gen/g.c gen/z doc/x.md \
         doc/a/b/x.md '#hash' 'sp ' trail ' lead' lead logs/a.txt logs/important/b.txt foo1.txt foo12.txt \
         Makefile.bak makefile.bak aXXb sub/a.log sub/local.txt local.txt sub/anchored.txt sub/x/anchored.txt \
         sub/nested/deep/f.tmp crlf/a.swp crlf/only/x root.tmp y.tmp z.orig .DS_Store; do
    : > "$f"
done
printf 'changed\n' >> README
cd - > /dev/null
compare_ignores "ignore rules" "$R"

# ------------------------------------------------------------ 2. .git
if "$B" --git -1 --no-color --no-icons "$R" | grep -qx '  \.git' \
   && ! "$B" --git -1 --no-color --no-icons "$R/.git" | grep -qv '^  '; then
    ok ".git and its contents carry no status"
else
    bad ".git or its contents carry a status"
fi
if "$B" --git -1 --no-color --no-icons "$R" | grep -qx 'M README'; then ok "modified tracked file is M"
else bad "modified tracked file is not M"; fi

# ------------------------------------------------------- 3. submodule
S="$T/subsrc"
$G init -q "$S"
printf 's\n' > "$S/s.txt"
$G -C "$S" add s.txt
$G -C "$S" commit -qm s
$G -C "$R" submodule add -q "$S" mod
$G -C "$R" commit -qm sub
if "$B" --git -1 --no-color --no-icons "$R" | grep -qx '\. mod'; then ok "submodule at its recorded commit is ."
else bad "submodule at its recorded commit is not ."; fi
if "$B" --git -1 --no-color --no-icons "$R/mod" | grep -qx '\. s\.txt'; then
    ok "a submodule's own files are listed through its gitdir: file"
else bad "submodule files not resolved through gitdir:"; fi
printf 'n\n' > "$R/mod/new.txt"
$G -C "$R/mod" add new.txt
$G -C "$R/mod" commit -qm move
if "$B" --git -1 --no-color --no-icons "$R" | grep -qx 'M mod'; then ok "submodule whose HEAD moved is M"
else bad "submodule whose HEAD moved is not M"; fi

# -------------------------------------------------- 4. linked worktree
$G -C "$R" worktree add -q "$T/wt" 2> /dev/null
: > "$T/wt/w.tmp"
out="$("$B" --git -1 --no-color --no-icons "$T/wt")"
if printf '%s\n' "$out" | grep -qx '\. src' && printf '%s\n' "$out" | grep -qx '! w\.tmp'; then
    ok "linked worktree: tracked files, and the common dir's info/exclude"
else
    bad "linked worktree:"; printf '%s\n' "$out" | head -10
fi
compare_ignores "worktree" "$T/wt"

# ------------------------------------------------------- 5. ownership
if sudo -n true 2> /dev/null; then
    O="$T/owned"
    $G init -q "$O"
    : > "$O/f"
    sudo -n chown -R 0:0 "$O"
    if [ "$("$B" --git -1 --no-color --no-icons "$O")" = "f" ]; then
        ok "another user's repository: no column"
    else bad "another user's repository still got a column"; fi
    printf '[safe]\n\tdirectory = %s\n' "$O" > "$HOME/.gitconfig"
    if [ "$("$B" --git -1 --no-color --no-icons "$O")" = "? f" ]; then
        ok "... until safe.directory lists it"
    else bad "safe.directory did not allow it"; fi
    printf '[safe]\n\tdirectory = *\n\tdirectory =\n' > "$HOME/.gitconfig"
    if [ "$("$B" --git -1 --no-color --no-icons "$O")" = "f" ]; then
        ok "an empty safe.directory resets the list"
    else bad "an empty safe.directory did not reset"; fi
    rm -f "$HOME/.gitconfig"
else
    echo "git-parity: skip ownership (no passwordless sudo)"
fi

exit $fail

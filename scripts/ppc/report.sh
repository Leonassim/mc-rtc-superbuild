#!/usr/bin/env bash
# Run diag.sh and push its output to the `ppc-reports` branch, so it can be
# read from another machine without copying anything by hand.
#
#   bash scripts/ppc/report.sh            # diag.sh
#   bash scripts/ppc/report.sh -- cmd...  # or any other command
#
# Deliberately built with plumbing (hash-object / mktree / commit-tree) rather
# than add+commit: it never touches your index, your working tree or HEAD, so
# it cannot disturb a build in progress and cannot make your branch diverge
# from what the other machine pushes. Reports accumulate -- each run chains
# onto the previous one, nothing is force-pushed.
set -u

cd "$(dirname "$0")/../.." || exit 1

BRANCH="${BRANCH:-ppc-reports}"
# The remote pointing at the fork, whatever it is called here.
REMOTE="${REMOTE:-$(git remote -v | awk '/leonassim.*\(push\)/{print $1; exit}')}"
REMOTE="${REMOTE:-origin}"

STAMP="$(date +%Y-%m-%d_%H-%M-%S)"
NAME="${STAMP}_$(hostname).txt"
OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

if [ "${1:-}" = "--" ]; then
  shift
  echo "\$ $*" > "$OUT"
  "$@" >> "$OUT" 2>&1
else
  bash "$(dirname "$0")/diag.sh" > "$OUT" 2>&1
fi

echo "--- $(wc -l < "$OUT") lignes capturees"

BLOB=$(git hash-object -w "$OUT") || exit 1
TREE=$(printf '100644 blob %s\t%s\n' "$BLOB" "$NAME" | git mktree) || exit 1

# Chain onto the existing report branch if there is one, so history keeps
# every run instead of overwriting the last.
if git fetch -q "$REMOTE" "$BRANCH" 2>/dev/null; then
  COMMIT=$(git commit-tree "$TREE" -p "$(git rev-parse FETCH_HEAD)" -m "ppc report $STAMP")
else
  COMMIT=$(git commit-tree "$TREE" -m "ppc report $STAMP")
fi

git push -q "$REMOTE" "$COMMIT:refs/heads/$BRANCH" && {
  echo "--- pousse sur $REMOTE/$BRANCH : $NAME"
} || {
  echo "--- push echoue. Le rapport est ici :"; cat "$OUT"
}

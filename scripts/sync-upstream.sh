#!/usr/bin/env bash
# Rebase-style sync: keep this fork exactly 1 commit ahead of xenodium/agent-shell.
#
# Soft-resets onto upstream/main, then recreates a single squashed patch commit
# (no merge commits).
#
# Usage:
#   ./scripts/sync-upstream.sh           # rewrite local main (no push)
#   ./scripts/sync-upstream.sh --push    # also force-with-lease push to origin
#
# Requires a clean working tree. Uncommitted work: commit or stash first.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

do_push=false
case "${1:-}" in
  --push) do_push=true ;;
  -h|--help)
    cat <<'EOF'
Rebase-style sync: keep this fork exactly 1 commit ahead of xenodium/agent-shell.

Soft-resets onto upstream/main, then recreates a single squashed patch commit
(no merge commits).

Usage:
  ./scripts/sync-upstream.sh           # rewrite local main (no push)
  ./scripts/sync-upstream.sh --push    # also force-with-lease push to origin

Requires a clean working tree. Uncommitted work: commit or stash first.
EOF
    exit 0
    ;;
  "")
    ;;
  *)
    echo "Unknown option: $1" >&2
    exit 2
    ;;
esac

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is dirty; commit or stash before syncing." >&2
  exit 1
fi

if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream https://github.com/xenodium/agent-shell.git
fi

git fetch --no-tags upstream main

upstream=$(git rev-parse upstream/main)
ahead=$(git rev-list --count "${upstream}..HEAD")

if [[ "$(git rev-parse HEAD)" == "${upstream}" ]]; then
  echo "Already matches upstream/main ($(git rev-parse --short "${upstream}"))."
  exit 0
fi

if git merge-base --is-ancestor "${upstream}" HEAD \
  && [[ "${ahead}" -eq 1 ]] \
  && [[ "$(git rev-parse HEAD^)" == "${upstream}" ]]; then
  echo "Already exactly 1 commit ahead of upstream/main ($(git rev-parse --short "${upstream}"))."
  if [[ "${do_push}" == true ]]; then
    git push --force-with-lease origin HEAD
  fi
  exit 0
fi

if [[ "${ahead}" -eq 1 ]]; then
  msg=$(git log -1 --format=%B HEAD)
else
  msg=$(
    cat <<EOF
dezzw patches on xenodium/agent-shell

Squashed fork-only commits:
$(git log --oneline "${upstream}..HEAD")
EOF
  )
fi

echo "Squashing ${ahead} fork-only commit(s) onto upstream/main ($(git rev-parse --short "${upstream}"))..."
git reset --soft "${upstream}"

if git diff --cached --quiet; then
  echo "No fork-only changes left; resetting main to upstream/main."
  git reset --hard "${upstream}"
else
  git commit -m "${msg}"
  echo "Now 1 ahead: $(git rev-parse --short HEAD)"
fi

if [[ "${do_push}" == true ]]; then
  git push --force-with-lease origin HEAD
  echo "Pushed with --force-with-lease."
else
  echo "Done. Push when ready: git push --force-with-lease origin HEAD"
fi

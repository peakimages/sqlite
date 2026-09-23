#!/usr/bin/env bash
set -euo pipefail

BOLD=$'\033[1m' DIM=$'\033[2m' GREEN=$'\033[32m' BLUE=$'\033[34m' RED=$'\033[31m' RESET=$'\033[0m'

heading() { printf '\n  %s%s%s\n' "$BOLD" "$*" "$RESET"; }
info() { printf '  %sℹ%s %s\n' "$BLUE" "$RESET" "$*"; }
ok() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
die() {
	printf '  %s✖%s %s\n' "$RED" "$RESET" "$*" >&2
	exit 1
}
confirm() {
	local answer
	printf '\n  %s [y/N] ' "$*"
	read -r answer
	[[ "$answer" =~ ^[Yy]$ ]]
}

cd "$(dirname "$0")/.."

main() {
	check_repository
	heading "Undoing $(git log -1 --format='%h %s')"
	info "resets the commit and restores src/Dockerfile and CHANGELOG.md"
	confirm "Continue?" || die "aborted, nothing changed"
	undo_commit
}

check_repository() {
	local subject
	git rev-parse --is-inside-work-tree > /dev/null 2>&1 || die "$PWD is not a git repository"
	subject="$(git log -1 --format=%s)"
	[[ "$subject" == "feat(release): bump image version to v"* ]] || die "the last commit is not a release commit: $subject"
	git fetch --quiet origin || die "could not fetch origin"
	[ "$(git rev-list --count origin/main..HEAD)" -ge 1 ] || die "the release commit is on origin/main already, nothing to undo locally"
}

undo_commit() {
	git reset --quiet --soft HEAD~1
	git restore --staged --worktree src/Dockerfile CHANGELOG.md
	ok "reset to $DIM$(git rev-parse --short HEAD)$RESET $(git log -1 --format=%s)"
	ok "src/Dockerfile is back to IMAGE_VERSION $BOLD$(sed -nE 's/^ARG IMAGE_VERSION=(.*)$/\1/p' src/Dockerfile)$RESET, the entries are back under [Unreleased]"
}

main

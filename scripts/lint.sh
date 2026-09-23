#!/usr/bin/env bash
set -euo pipefail

HADOLINT=hadolint/hadolint:v2.15.1
SHELLCHECK=koalaman/shellcheck:v0.11.0
SHFMT=mvdan/shfmt:v3.14.1
ACTIONLINT=rhysd/actionlint:1.7.12
EDITORCONFIG_CHECKER=mstruebing/editorconfig-checker:4.0.2

BOLD=$'\033[1m' GREEN=$'\033[32m' BLUE=$'\033[34m' RED=$'\033[31m' RESET=$'\033[0m'

heading() { printf '\n  %s%s%s\n' "$BOLD" "$*" "$RESET"; }
info() { printf '  %sℹ%s %s\n' "$BLUE" "$RESET" "$*"; }
ok() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
err() { printf '  %s✖%s %s\n' "$RED" "$RESET" "$*" >&2; }
die() {
	err "$@"
	exit 1
}

cd "$(dirname "$0")/.."
failed=0

main() {
	command -v docker > /dev/null || die "docker is not installed"
	docker info > /dev/null 2>&1 || die "docker is not running"
	case "${1:-}" in
		"") ;;
		--fix) format ;;
		*) die "usage: scripts/lint.sh [--fix]" ;;
	esac
	heading "Linting"
	check src/Dockerfile hadolint "$HADOLINT" hadolint src/Dockerfile
	check "the shell scripts" ShellCheck "$SHELLCHECK" scripts/*.sh src/*.sh src/rootfs/usr/local/bin/*.sh
	check "the shell scripts" shfmt "$SHFMT" -d scripts src
	check "the workflows" actionlint "$ACTIONLINT"
	check "every file" editorconfig-checker "$EDITORCONFIG_CHECKER" editorconfig-checker -exclude '^LICENSE$'
	[ "$failed" = 0 ] || die "$failed of 5 checks failed"
	heading "All checks passed"
}

format() {
	heading "Formatting"
	tool "$SHFMT" -w scripts src
	tool "$EDITORCONFIG_CHECKER" editorconfig-checker -fix -exclude '^LICENSE$' > /dev/null || true
	ok "shfmt and editorconfig-checker wrote their fixes"
}

check() {
	local files="$1" linter="$2" image="$3"
	shift 3
	if tool "$image" "$@"; then
		ok "$files passed $linter"
	else
		err "$files failed $linter"
		failed=$((failed + 1))
	fi
}

tool() {
	if ! docker image inspect "$1" > /dev/null 2>&1; then
		info "pulling $1"
		docker pull --quiet "$1" > /dev/null
	fi
	docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/mnt" -w /mnt "$@"
}

main "$@"

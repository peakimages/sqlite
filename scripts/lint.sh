#!/usr/bin/env bash
set -euo pipefail

OPTION="$*"
# https://github.com/hadolint/hadolint/releases/tag/v2.15.1
HADOLINT=hadolint/hadolint:v2.15.1
# https://github.com/koalaman/shellcheck/releases/tag/v0.11.0
SHELLCHECK=koalaman/shellcheck:v0.11.0
# https://github.com/mvdan/sh/releases/tag/v3.14.1
SHFMT=mvdan/shfmt:v3.14.1
# https://github.com/jdx/jactionlint/releases/tag/v2.2.0
JACTIONLINT=ghcr.io/jdx/jactionlint:2.2.0
# https://github.com/editorconfig-checker/editorconfig-checker/releases/tag/v4.0.2
EDITORCONFIG_CHECKER=mstruebing/editorconfig-checker:4.0.2

BOLD=$'\033[1m' BLUE=$'\033[34m' GREEN=$'\033[32m' RED=$'\033[31m' RESET=$'\033[0m'

heading() { printf '\n  %s%s%s\n' "$BOLD" "$*" "$RESET"; }
info() { printf '  %sℹ%s %s\n' "$BLUE" "$RESET" "$*"; }
ok() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
die() {
	printf '  %s✖%s %s\n' "$RED" "$RESET" "$*" >&2
	exit 1
}

cd "$(dirname "$0")/.."

main() {
	[[ "$OPTION" =~ ^(--fix)?$ ]] || die "'$OPTION' is not an option, expected --fix or none"
	command -v docker > /dev/null || die "docker is not installed"
	docker info > /dev/null 2>&1 || die "docker is not running"
	[ "$OPTION" != --fix ] || format
	heading "Linting"
	run_build_checks
	check src/Dockerfile hadolint "$HADOLINT" hadolint src/Dockerfile
	check "the shell scripts" ShellCheck "$SHELLCHECK" scripts/*.sh src/*.sh src/rootfs/usr/local/bin/*.sh
	check "the shell scripts" shfmt "$SHFMT" -d scripts src
	check "the workflows" jactionlint "$JACTIONLINT" --strict-exit
	check "every file" editorconfig-checker "$EDITORCONFIG_CHECKER" editorconfig-checker -exclude '^LICENSE$'
	heading "All checks passed"
}

format() {
	heading "Formatting"
	tool "$SHFMT" -w scripts src
	tool "$EDITORCONFIG_CHECKER" editorconfig-checker -fix -exclude '^LICENSE$' > /dev/null || true
	ok "shfmt and editorconfig-checker wrote their fixes"
}

run_build_checks() {
	docker build --check --progress=quiet src | sed 1d || die "src/Dockerfile failed docker build --check"
	ok "src/Dockerfile passed docker build --check"
}

check() {
	local files="$1" linter="$2" image="$3"
	shift 3
	tool "$image" "$@" || die "$files failed $linter"
	ok "$files passed $linter"
}

tool() {
	if ! docker image inspect "$1" > /dev/null 2>&1; then
		info "pulling $1"
		docker pull --quiet "$1" > /dev/null
	fi
	docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/mnt" -w /mnt "$@"
}

main

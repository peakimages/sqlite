#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="$(mktemp -d)"

BOLD=$'\033[1m' GREEN=$'\033[32m' BLUE=$'\033[34m' RED=$'\033[31m' RESET=$'\033[0m'

info() { printf '  %sℹ%s %s\n' "$BLUE" "$RESET" "$*"; }
ok() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
die() {
	printf '  %s✖%s %s\n' "$RED" "$RESET" "$*" >&2
	exit 1
}

cd "$(dirname "$0")/.."
trap 'rm -rf "$WORK_DIR"' EXIT

main() {
	read_latest_release
	compare_with_pinned
	download_amalgamation
	write_version_json
	verify_amalgamation
	update_dockerfile
}

read_latest_release() {
	local release
	fetch "$WORK_DIR/download.html" https://sqlite.org/download.html
	release="$(grep -Em 1 '^PRODUCT,[0-9.]+,[0-9]{4}/sqlite-amalgamation-[0-9]+\.zip,[0-9]+,[0-9a-f]{64}$' "$WORK_DIR/download.html")" \
		|| die "no amalgamation listed on sqlite.org/download.html"
	IFS=, read -r _ version path size sha3 <<< "$release"
	url="https://sqlite.org/$path"
}

compare_with_pinned() {
	local pinned
	pinned="$(jq -r .version src/version.json)"
	if [ "$version" = "$pinned" ]; then
		ok "SQLite $BOLD$pinned$RESET is pinned and the current release on sqlite.org"
		exit 0
	fi
	info "sqlite.org lists SQLite $BOLD$version$RESET, $pinned is pinned"
}

download_amalgamation() {
	fetch "$WORK_DIR/sqlite.zip" "$url"
	source_id="$(unzip -p "$WORK_DIR/sqlite.zip" '*/sqlite3.h' | sed -nE 's/^#define SQLITE_SOURCE_ID +"([^"]+)".*/\1/p')"
	[ -n "$source_id" ] || die "sqlite3.h in the download does not define SQLITE_SOURCE_ID"
	ok "downloaded ${url##*/}, $size bytes"
}

write_version_json() {
	jq -n --arg version "$version" --arg url "$url" --argjson size "$size" --arg sha3_256 "$sha3" --arg source_id "$source_id" \
		'{$version, $url, $size, $sha3_256, $source_id}' > src/version.json
	ok "src/version.json pins $BOLD$version$RESET with url, size, SHA3-256 and source id $source_id"
}

verify_amalgamation() {
	cp src/verify.sh src/version.json "$WORK_DIR"
	SQLITE_VERSION="$version" sh "$WORK_DIR/verify.sh" > /dev/null
	ok "src/verify.sh accepts the download against the new src/version.json"
}

update_dockerfile() {
	sed -E "s|^ARG SQLITE_VERSION=.*|ARG SQLITE_VERSION=$version|" src/Dockerfile > "$WORK_DIR/Dockerfile"
	cp "$WORK_DIR/Dockerfile" src/Dockerfile
	ok "src/Dockerfile sets SQLITE_VERSION $BOLD$version$RESET"
}

fetch() {
	curl --proto '=https' --tlsv1.2 -sSf --retry 3 -o "$1" "$2"
}

main

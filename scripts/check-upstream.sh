#!/usr/bin/env bash
set -euo pipefail

OPTION="$*"
LINE="${1:-latest}"
VERSION_PATTERN='[0-9]+\.[0-9]+\.[0-9]+'
WORK_DIR="$(mktemp -d)"

BOLD=$'\033[1m' BLUE=$'\033[34m' GREEN=$'\033[32m' RED=$'\033[31m' RESET=$'\033[0m'

info() { printf '  %sℹ%s %s\n' "$BLUE" "$RESET" "$*"; }
ok() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
die() {
	printf '  %s✖%s %s\n' "$RED" "$RESET" "$*" >&2
	exit 1
}

cd "$(dirname "$0")/.."
trap 'rm -rf "$WORK_DIR"' EXIT

main() {
	[[ "$OPTION" =~ ^(latest|[0-9]+(\.[0-9]+)*)?$ ]] || die "'$OPTION' is not an option, expected a line such as 3.53, latest or none"
	read_newest_release
	compare_with_pinned
	download_amalgamation
	verify_release_notes
	verify_release_check_in
	write_upstream_json
	verify_amalgamation
	update_dockerfile
}

read_newest_release() {
	local release year number
	fetch "$WORK_DIR/chronology.html" https://sqlite.org/chronology.html
	release="$(sed -nE "s|.*>([0-9]{4})-[0-9]{2}-[0-9]{2}</a></td>\$|year \1|p; s|.*data-sortkey='([0-9]+)'><a href=\"releaselog/[0-9_]+\.html\">($VERSION_PATTERN)</a>.*|version \1 \2|p" "$WORK_DIR/chronology.html" \
		| awk -v line="$LINE." '$1 == "year" { year = $2 } $1 == "version" && (line == "latest." || index($3 ".", line) == 1) { print year, $2, $3 }' \
		| sort -k3,3V | tail -n 1)"
	[ -n "$release" ] || die "sqlite.org/chronology.html lists no SQLite $LINE release"
	read -r year number new_version <<< "$release"
	url="https://sqlite.org/$year/sqlite-amalgamation-$number.zip"
}

compare_with_pinned() {
	local current_version
	current_version="$(jq -r --arg line "$LINE" '.sqlite[$line].version // empty' src/upstream.json)"
	if [ "$new_version" = "$current_version" ]; then
		ok "SQLite $BOLD$current_version$RESET is pinned as $LINE and the newest release of it on sqlite.org"
		exit 0
	fi
	info "sqlite.org lists SQLite $BOLD$new_version$RESET, ${current_version:-no version} is pinned as $LINE"
}

download_amalgamation() {
	fetch "$WORK_DIR/sqlite.zip" "$url"
	size="$(wc -c < "$WORK_DIR/sqlite.zip" | tr -d ' ')"
	sha3="$(openssl dgst -sha3-256 -r "$WORK_DIR/sqlite.zip" | cut -d ' ' -f 1)"
	source_id="$(unzip -p "$WORK_DIR/sqlite.zip" '*/sqlite3.h' | sed -nE 's/^#define SQLITE_SOURCE_ID +"([^"]+)".*/\1/p')"
	[ -n "$source_id" ] || die "sqlite3.h in the download does not define SQLITE_SOURCE_ID"
	ok "downloaded ${url##*/}, $size bytes"
}

verify_release_notes() {
	local sqlite3_c
	fetch "$WORK_DIR/release.html" "https://sqlite.org/releaselog/${new_version//./_}.html"
	sqlite3_c="$(unzip -p "$WORK_DIR/sqlite.zip" '*/sqlite3.c' | openssl dgst -sha3-256 -r | cut -d ' ' -f 1)"
	grep -qxF "<li>SQLITE_SOURCE_ID: $source_id" "$WORK_DIR/release.html" || die "the release notes of SQLite $new_version list another source id than $source_id"
	grep -qxF "<li>SHA3-256 for sqlite3.c: $sqlite3_c" "$WORK_DIR/release.html" || die "the release notes of SQLite $new_version list another SHA3-256 for sqlite3.c than $sqlite3_c"
	ok "the release notes of SQLite $new_version list the source id and the SHA3-256 of sqlite3.c in the download"
}

verify_release_check_in() {
	local check_in tag
	check_in="${source_id##* }"
	fetch "$WORK_DIR/manifest" "https://sqlite.org/src/raw/$check_in"
	for tag in release "version-$new_version"; do
		grep -qxF "T +sym-$tag *" "$WORK_DIR/manifest" || die "check-in ${check_in:0:10} on sqlite.org/src is not tagged $tag"
	done
	ok "check-in ${check_in:0:10} is tagged release and ${BOLD}version-$new_version$RESET on sqlite.org/src"
}

write_upstream_json() {
	jq --tab --arg line "$LINE" --arg version "$new_version" --arg url "$url" --argjson size "$size" --arg sha3_256 "$sha3" --arg source_id "$source_id" \
		'.sqlite[$line] = {$version, $url, $size, $sha3_256, $source_id}' src/upstream.json > "$WORK_DIR/upstream.json"
	cp "$WORK_DIR/upstream.json" src/upstream.json
	ok "src/upstream.json pins $BOLD$new_version$RESET as $LINE with url, size, SHA3-256 and source id $source_id"
}

verify_amalgamation() {
	cp src/verify.sh "$WORK_DIR"
	jq --arg line "$LINE" '.sqlite[$line]' src/upstream.json > "$WORK_DIR/sqlite.json"
	SQLITE_VERSION="$new_version" sh "$WORK_DIR/verify.sh" > /dev/null
	ok "src/verify.sh accepts the download against the new pin"
}

update_dockerfile() {
	[ "$LINE" = latest ] || return 0
	sed -E "s|^ARG SQLITE_VERSION=.*|ARG SQLITE_VERSION=$new_version|" src/Dockerfile > "$WORK_DIR/Dockerfile"
	cp "$WORK_DIR/Dockerfile" src/Dockerfile
	ok "src/Dockerfile sets SQLITE_VERSION $BOLD$new_version$RESET"
}

fetch() {
	curl --proto '=https' --tlsv1.2 -sSf --retry 3 -o "$1" "$2"
}

main

#!/bin/sh
set -eu

cd "$(dirname "$0")"

die() {
	echo "verify: $*" >&2
	exit 1
}

main() {
	check_version
	check_download
	unpack
	check_header
	echo "verify: SQLite $SQLITE_VERSION, $(pin size) bytes, SHA3-256 and source id match"
}

check_version() {
	[ "$(pin version)" = "$SQLITE_VERSION" ] || die "version.json pins $(pin version), the Dockerfile says $SQLITE_VERSION"
}

check_download() {
	size="$(wc -c < sqlite.zip | tr -d ' ')"
	[ "$size" = "$(pin size)" ] || die "sqlite.zip has $size bytes, expected $(pin size)"
	[ "$(openssl dgst -sha3-256 -r sqlite.zip | cut -d ' ' -f 1)" = "$(pin sha3_256)" ] || die "SHA3-256 of sqlite.zip does not match version.json"
}

unpack() {
	unzip -q sqlite.zip
	mv sqlite-amalgamation-* sqlite
}

check_header() {
	grep -qE "^#define SQLITE_VERSION +\"$SQLITE_VERSION\"$" sqlite/sqlite3.h || die "sqlite3.h does not define SQLITE_VERSION $SQLITE_VERSION"
	grep -qE "^#define SQLITE_SOURCE_ID +\"$(pin source_id)\"$" sqlite/sqlite3.h || die "sqlite3.h does not define SQLITE_SOURCE_ID $(pin source_id)"
}

pin() {
	jq -r ".$1" version.json
}

main

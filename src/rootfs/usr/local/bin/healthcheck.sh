#!/bin/sh
set -euf

DATA_DIR=/var/lib/sqlite

main() {
	[ "$#" -gt 0 ] || set -- "${SQLITE_DATABASES:-database.sqlite}"
	for name in $(printf '%s' "$*" | tr ',' ' '); do
		read_without_lock "$DATA_DIR/$name" || read_with_lock "$DATA_DIR/$name"
	done
}

read_without_lock() {
	sqlite3 -readonly "file:$1?immutable=1" 'PRAGMA schema_version;' > /dev/null 2>&1
}

read_with_lock() {
	sqlite3 -readonly -cmd '.timeout 3000' "$1" 'PRAGMA schema_version;' > /dev/null
}

main "$@"

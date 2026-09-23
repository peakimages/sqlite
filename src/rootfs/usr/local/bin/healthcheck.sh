#!/bin/sh
set -euf

DATA_DIR=/var/lib/sqlite

main() {
	[ "$#" -gt 0 ] || set -- "${SQLITE_DATABASES:-database.sqlite}"
	for name in $(printf '%s' "$*" | tr ',' ' '); do
		sqlite3 -readonly "$DATA_DIR/$name" 'PRAGMA schema_version;' > /dev/null
	done
}

main "$@"

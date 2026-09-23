#!/bin/sh
set -euf

DATA_DIR=/var/lib/sqlite

die() {
	echo "docker-entrypoint: $*" >&2
	exit 1
}

main() {
	[ "$#" -eq 0 ] || run "$@"
	validate_settings
	validate_databases
	for name in $databases; do
		[ -e "$DATA_DIR/$name" ] || create_database "$name"
	done
	exec sleep infinity
}

run() {
	case "$1" in
		-*) exec sqlite3 "$@" ;;
		*/*) [ -x "$1" ] && exec "$@" ;;
		*) command -v "$1" > /dev/null && exec "$@" ;;
	esac
	exec sqlite3 "$@"
}

validate_settings() {
	journal_mode="$(printf '%s' "${SQLITE_JOURNAL_MODE:-WAL}" | tr '[:upper:]' '[:lower:]')"
	case "$journal_mode" in
		wal | delete | truncate | persist | memory | off) ;;
		*) die "SQLITE_JOURNAL_MODE must be WAL, DELETE, TRUNCATE, PERSIST, MEMORY or OFF, not '$SQLITE_JOURNAL_MODE'" ;;
	esac
	auto_vacuum="$(printf '%s' "${SQLITE_AUTO_VACUUM:-NONE}" | tr '[:upper:]' '[:lower:]')"
	case "$auto_vacuum" in
		none | full | incremental) ;;
		*) die "SQLITE_AUTO_VACUUM must be NONE, FULL or INCREMENTAL, not '$SQLITE_AUTO_VACUUM'" ;;
	esac
	page_size="${SQLITE_PAGE_SIZE:-4096}"
	case "$page_size" in
		512 | 1024 | 2048 | 4096 | 8192 | 16384 | 32768 | 65536) ;;
		*) die "SQLITE_PAGE_SIZE must be a power of two from 512 to 65536, not '$page_size'" ;;
	esac
}

validate_databases() {
	databases="$(printf '%s' "${SQLITE_DATABASES:-database.sqlite}" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; /./!d')"
	[ -n "$databases" ] || die "SQLITE_DATABASES names no file"
	case "$databases" in
		*[[:blank:]]*) die "whitespace inside a name in SQLITE_DATABASES, separate names with commas: '$SQLITE_DATABASES'" ;;
	esac
	for name in $databases; do
		case "$name" in
			*[!A-Za-z0-9._-]* | [.-]*) die "'$name' in SQLITE_DATABASES is not a plain file name" ;;
		esac
	done
}

create_database() {
	sqlite3 "$DATA_DIR/$1" "PRAGMA page_size=$page_size; PRAGMA auto_vacuum=$auto_vacuum; PRAGMA user_version=0; PRAGMA journal_mode=$journal_mode;" > /dev/null
	echo "docker-entrypoint: created $1, page size $page_size, auto_vacuum $auto_vacuum, journal mode $journal_mode"
}

main "$@"

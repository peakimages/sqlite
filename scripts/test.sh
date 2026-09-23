#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:?usage: scripts/test.sh IMAGE}"
CONTAINER=sqlite-test
WORK_DIR="$(mktemp -d)"

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' RESET=$'\033[0m'

heading() { printf '\n  %s%s%s\n' "$BOLD" "$*" "$RESET"; }
ok() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
die() {
	printf '  %s✖%s %s\n' "$RED" "$RESET" "$*" >&2
	exit 1
}

cd "$(dirname "$0")/.."
trap cleanup EXIT

main() {
	heading "Testing $IMAGE"
	check_version
	check_default_database
	heading "Container"
	start_container
	check_databases
	check_healthcheck
	check_restart
	check_creation_settings
	check_rejected_settings
	heading "Data"
	seed_database
	backup_database
	restore_database
	check_stop
	heading "All tests passed for $IMAGE"
}

check_version() {
	local printed version source_id
	printed="$(docker run --rm "$IMAGE" --version)"
	version="$(jq -r .version src/version.json)"
	source_id="$(jq -r .source_id src/version.json)"
	[[ "$printed" == "$version $source_id "* ]] || die "sqlite3 --version prints '$printed', expected '$version $source_id'"
	ok "sqlite3 --version prints $version with the source id from src/version.json"
}

check_default_database() {
	local settings
	docker run -d --name "$CONTAINER-default" --health-interval 2s --health-start-period 1s "$IMAGE" > /dev/null
	wait_healthy "$CONTAINER-default"
	settings="$(docker exec "$CONTAINER-default" sqlite3 database.sqlite 'PRAGMA page_size; PRAGMA auto_vacuum; PRAGMA journal_mode;' | tr '\n' ' ')"
	[ "$settings" = '4096 0 wal ' ] || die "database.sqlite was created with '$settings', expected page size 4096, no auto-vacuum, WAL"
	ok "database.sqlite is created by default with page size 4096, no auto-vacuum and WAL"
}

start_container() {
	docker volume create "$CONTAINER" > /dev/null
	docker run -d --name "$CONTAINER" -v "$CONTAINER:/var/lib/sqlite" \
		--read-only --cap-drop ALL --security-opt no-new-privileges \
		-e SQLITE_DATABASES="app.sqlite,jobs.sqlite" \
		--health-interval 2s --health-start-period 1s "$IMAGE" > /dev/null
	wait_healthy "$CONTAINER"
	docker exec "$CONTAINER" ps -o args | grep -qx 'sleep infinity' || die "the main process is not sleep infinity"
	ok "healthy with a read-only root filesystem and all capabilities dropped, main process sleep infinity"
}

check_databases() {
	local owner
	[ "$(sql app.sqlite 'PRAGMA journal_mode;')" = wal ] || die "app.sqlite is not in WAL mode"
	[ "$(sql jobs.sqlite 'PRAGMA journal_mode;')" = wal ] || die "jobs.sqlite is not in WAL mode"
	owner="$(docker exec "$CONTAINER" stat -c '%u:%g' jobs.sqlite)"
	[ "$owner" = 65532:65532 ] || die "jobs.sqlite is owned by $owner, expected 65532:65532"
	ok "app.sqlite and jobs.sqlite from SQLITE_DATABASES are created in WAL mode, owned by $owner"
}

check_healthcheck() {
	docker exec "$CONTAINER" healthcheck.sh app.sqlite,jobs.sqlite || die "healthcheck.sh app.sqlite,jobs.sqlite failed"
	docker exec "$CONTAINER" healthcheck.sh app.sqlite,missing.sqlite 2> /dev/null && die "healthcheck.sh passed with a missing file"
	ok "healthcheck.sh passes for app.sqlite,jobs.sqlite and fails as soon as one file is missing"
}

check_restart() {
	sql app.sqlite 'PRAGMA journal_mode=DELETE;' > /dev/null
	docker restart -t 5 "$CONTAINER" > /dev/null
	wait_healthy "$CONTAINER"
	[ "$(sql app.sqlite 'PRAGMA journal_mode;')" = delete ] || die "a restart changed the journal mode of an existing database"
	sql app.sqlite 'PRAGMA journal_mode=WAL;' > /dev/null
	ok "a restart leaves an existing database as it is"
}

check_creation_settings() {
	local files settings
	docker run -d --name "$CONTAINER-settings" \
		-e SQLITE_DATABASES=" one.sqlite, two.sqlite ,,three.sqlite " \
		-e SQLITE_JOURNAL_MODE=delete -e SQLITE_AUTO_VACUUM=incremental -e SQLITE_PAGE_SIZE=8192 \
		--health-interval 2s --health-start-period 1s "$IMAGE" > /dev/null
	wait_healthy "$CONTAINER-settings"
	files="$(docker exec "$CONTAINER-settings" ls | tr '\n' ' ')"
	[ "$files" = 'one.sqlite three.sqlite two.sqlite ' ] || die "SQLITE_DATABASES with whitespace around the commas created '$files'"
	settings="$(docker exec "$CONTAINER-settings" sqlite3 one.sqlite 'PRAGMA page_size; PRAGMA auto_vacuum; PRAGMA journal_mode;' | tr '\n' ' ')"
	[ "$settings" = '8192 2 delete ' ] || die "creation settings not applied, got '$settings'"
	ok "SQLITE_PAGE_SIZE, SQLITE_AUTO_VACUUM and SQLITE_JOURNAL_MODE apply to new databases, names are split on commas and trimmed"
}

check_rejected_settings() {
	local setting
	for setting in SQLITE_JOURNAL_MODE=journal SQLITE_AUTO_VACUUM=yes SQLITE_PAGE_SIZE=1000 \
		SQLITE_DATABASES=../x 'SQLITE_DATABASES=a.sqlite b.sqlite' 'SQLITE_DATABASES=a;b.sqlite' 'SQLITE_DATABASES=*' 'SQLITE_DATABASES= , '; do
		docker run --rm -e "$setting" "$IMAGE" > /dev/null 2>&1 && die "$setting was accepted"
	done
	ok "bad settings and names that are not plain file names are rejected"
}

seed_database() {
	sql app.sqlite \
		'CREATE TABLE t(id INTEGER PRIMARY KEY, body TEXT);' \
		"INSERT INTO t(body) VALUES ('one'),('two'),('three');" \
		'CREATE VIRTUAL TABLE docs USING fts5(body);' \
		"INSERT INTO docs VALUES ('sqlite rocks');" \
		'CREATE VIRTUAL TABLE legacy USING fts4(body);' \
		"INSERT INTO legacy VALUES ('fts4 works');" \
		'CREATE VIRTUAL TABLE geo USING rtree(id,minx,maxx);' \
		'INSERT INTO geo VALUES (1,0,10);' \
		'CREATE VIRTUAL TABLE shapes USING geopoly();' \
		"INSERT INTO shapes(_shape) VALUES ('[[0,0],[1,0],[1,1],[0,1],[0,0]]');"
	[ "$(sql app.sqlite "SELECT json_extract('{\"a\":1}','\$.a') + sqrt(16);")" = 5.0 ] || die "JSON or math functions"
	[ "$(sql app.sqlite "SELECT soundex('Robert');")" = R163 ] || die "soundex()"
	[ "$(sql app.sqlite 'SELECT count(*) > 0 FROM dbstat;')" = 1 ] || die "dbstat"
	[ "$(sql app.sqlite 'PRAGMA integrity_check;')" = ok ] || die "integrity check after seeding"
	ok "FTS3, FTS4, FTS5, R*Tree, Geopoly, JSON, math functions, soundex() and dbstat work"
}

backup_database() {
	local result
	docker exec "$CONTAINER" sh -c "sqlite3 app.sqlite \"VACUUM INTO 'backup.sqlite'\" && cat backup.sqlite && rm backup.sqlite" > "$WORK_DIR/backup.sqlite"
	result="$(docker run --rm -i "$IMAGE" sh -c 'cat > backup.sqlite && sqlite3 backup.sqlite "PRAGMA integrity_check; SELECT count(*) FROM t;"' < "$WORK_DIR/backup.sqlite" | tr '\n' ' ')"
	[ "$result" = 'ok 3 ' ] || die "the backup is not intact and complete, got '$result'"
	ok "a backup with VACUUM INTO streams out through docker exec, intact and complete"
}

restore_database() {
	local result
	sql app.sqlite 'DELETE FROM t;'
	docker exec -i "$CONTAINER" sh -c 'cat > restore.sqlite && sqlite3 app.sqlite ".restore restore.sqlite" && rm restore.sqlite' < "$WORK_DIR/backup.sqlite"
	result="$(sql app.sqlite 'PRAGMA integrity_check; PRAGMA journal_mode; SELECT count(*) FROM t;' | tr '\n' ' ')"
	[ "$result" = 'ok wal 3 ' ] || die "the restored database is not intact, got '$result'"
	[ "$(sql app.sqlite "SELECT body FROM docs WHERE docs MATCH 'sqlite';")" = 'sqlite rocks' ] || die "FTS5 after restore"
	[ "$(sql app.sqlite "SELECT body FROM legacy WHERE legacy MATCH 'fts4';")" = 'fts4 works' ] || die "FTS4 after restore"
	ok "a restore with .restore streams in through docker exec, the rows are back, WAL kept, FTS readable"
}

check_stop() {
	local code
	docker stop -t 5 "$CONTAINER" > /dev/null
	code="$(docker inspect -f '{{.State.ExitCode}}' "$CONTAINER")"
	[ "$code" = 143 ] || die "exit code $code, expected 143 (terminated by SIGTERM)"
	[ "$(docker run --rm -v "$CONTAINER:/var/lib/sqlite" "$IMAGE" app.sqlite 'PRAGMA integrity_check;')" = ok ] || die "integrity check after stop"
	ok "docker stop exits with 143 on SIGTERM and leaves app.sqlite intact"
}

wait_healthy() {
	for _ in $(seq 30); do
		[ "$(docker inspect -f '{{.State.Health.Status}}' "$1")" = healthy ] && return
		sleep 1
	done
	die "$1 did not become healthy: $(docker logs "$1" 2>&1 | tail -n 3)"
}

sql() {
	docker exec "$CONTAINER" sqlite3 "$@"
}

cleanup() {
	docker rm -f "$CONTAINER" "$CONTAINER-default" "$CONTAINER-settings" > /dev/null 2>&1 || true
	docker volume rm -f "$CONTAINER" > /dev/null 2>&1 || true
	rm -rf "$WORK_DIR"
}

main

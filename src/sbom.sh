#!/bin/sh
set -eu

USAGE="usage: sbom.sh IMAGE FULL_NAME COMPONENT..., a component is apk|NAME|PATH,..., deb|NAME|PATH,... or generic|NAME|VERSION|LICENSE|VENDOR:PRODUCT|PATH"
IMAGE="${1:-}"
FULL_NAME="${2:-}"
ROOT_DIR="${ROOT_DIR:-/rootfs}"
APK_DATABASE="$ROOT_DIR/lib/apk/db/installed"
DPKG_DATABASE="$ROOT_DIR/var/lib/dpkg/status.d"

die() {
	echo "sbom: $*" >&2
	exit 1
}

main() {
	[ "$#" -gt 2 ] || die "$USAGE"
	shift 2
	for component in "$@"; do
		case "$component" in
			apk\|*\|*) write_apk_record "${component#apk|}" ;;
			deb\|*\|*) write_deb_record "${component#deb|}" ;;
			generic\|*) write_note "${component#generic|}" ;;
			*) die "'$component' is not a component, $USAGE" ;;
		esac
	done
	write_os_release
	echo "sbom: $ROOT_DIR declares $(printf '%s\n' "$@" | cut -d '|' -f 2 | paste -sd , - | sed 's/,/, /g')"
}

write_apk_record() {
	name="${1%%|*}"
	mkdir -p "${APK_DATABASE%/*}"
	{
		awk -v RS= -v name="$name" 'index("\n" $0 "\n", "\nP:" name "\n") { sub(/\nF:.*/, ""); print; found = 1 } END { exit !found }' /lib/apk/db/installed \
			|| die "$name is not installed"
		for path in $(echo "${1#*|}" | tr ',' ' '); do
			[ -e "$ROOT_DIR$path" ] || die "$path is not in $ROOT_DIR"
			if [ -d "$ROOT_DIR$path" ]; then
				echo "F:${path#/}"
			else
				printf 'F:%s\nR:%s\n' "$(dirname "${path#/}")" "${path##*/}"
			fi
		done
		echo
	} >> "$APK_DATABASE"
}

write_deb_record() {
	name="${1%%|*}"
	mkdir -p "$DPKG_DATABASE"
	awk -v RS= -v name="$name" 'index("\n" $0 "\n", "\nPackage: " name "\n") { sub(/\nConffiles:(\n [^\n]*)*/, ""); print; found = 1 } END { exit !found }' /var/lib/dpkg/status > "$DPKG_DATABASE/$name" \
		|| die "$name is not installed"
	for path in $(echo "${1#*|}" | tr ',' ' '); do
		[ -e "$ROOT_DIR$path" ] || die "$path is not in $ROOT_DIR"
		(cd "$ROOT_DIR" && find "${path#/}" -type f -exec md5sum {} +)
	done > "$DPKG_DATABASE/$name.md5sums"
	install -D -m 0644 "/usr/share/doc/$name/copyright" "$ROOT_DIR/usr/share/doc/$name/copyright"
	install -D -m 0644 /etc/debian_version "$ROOT_DIR/etc/debian_version"
}

write_note() {
	path="${1##*|}"
	[ -f "$ROOT_DIR$path" ] || die "$path is not in $ROOT_DIR"
	note="$(echo "$1" | jq -Rce 'split("|") | select(length == 5 and (.[3] | test("^[a-z0-9._-]+:[a-z0-9._-]+$"))) | { type: "generic", name: .[0], version: .[1], license: .[2], appCpe: "cpe:2.3:a:\(.[3]):\(.[1]):*:*:*:*:*:*:*" }')" \
		|| die "'generic|$1' is not a component, $USAGE"
	as -o /src/note.o /dev/null
	ld -shared --package-metadata="$note" -o /src/note.so /src/note.o
	objcopy -O binary --only-section=.note.package /src/note.so /src/note
	objcopy --add-section .note.package=/src/note "$ROOT_DIR$path"
	objcopy --set-section-alignment .note.package=4 "$ROOT_DIR$path"
}

write_os_release() {
	[ -e "$APK_DATABASE" ] || [ -d "$DPKG_DATABASE" ] || return 0
	distribution="$(awk -F= '{ gsub(/"/, "", $2) } $1 == "NAME" { name = $2 } $1 == "VERSION_ID" { version = $2 } END { print name, version }' /etc/os-release)"
	{
		printf 'NAME="%s"\n' "$FULL_NAME"
		grep -Ev '^(PRETTY_NAME|NAME|[A-Z_]+_URL)=' /etc/os-release
		printf 'PRETTY_NAME="%s (packages from %s)"\n' "$FULL_NAME" "$distribution"
		printf 'HOME_URL="https://github.com/%s"\nBUG_REPORT_URL="https://github.com/%s/issues"\n' "$IMAGE" "$IMAGE"
	} > "$ROOT_DIR/etc/os-release"
}

main "$@"

#!/bin/sh
set -eu

APPLETS="
	sh cat cp mv rm ls ln mkdir rmdir chmod chown stat date env printf echo test [
	sleep timeout find xargs wc head tail tee du df id ps kill sync tty which yes true false
	gzip gunzip zcat tar sort uniq cut tr grep sed awk diff cmp split truncate od hexdump
	basename dirname readlink realpath touch pwd uname hostname whoami nproc seq expr
	mktemp md5sum sha256sum sha3sum base64 less vi
"

die() {
	echo "rootfs: $*" >&2
	exit 1
}

main() {
	install_binaries
	create_user
	create_directories
	link_applets
	echo "rootfs: sqlite3, tini, busybox and the applets installed"
}

install_binaries() {
	install -D -m 0755 /src/sqlite/sqlite3 /rootfs/usr/local/bin/sqlite3
	install -D -m 0755 /sbin/tini-static /rootfs/sbin/tini
	install -D -m 0755 /bin/busybox.static /rootfs/bin/busybox
	chmod 0755 /rootfs/usr/local/bin/*.sh
}

create_user() {
	install -d /rootfs/etc
	echo "nonroot:x:$SQLITE_UID:$SQLITE_GID::/var/lib/sqlite:/sbin/nologin" > /rootfs/etc/passwd
	echo "nonroot:x:$SQLITE_GID:" > /rootfs/etc/group
}

create_directories() {
	install -d -m 0700 -o "$SQLITE_UID" -g "$SQLITE_GID" /rootfs/var/lib/sqlite
	install -d -m 1777 /rootfs/tmp
}

link_applets() {
	for applet in $APPLETS; do
		/rootfs/bin/busybox --list | grep -qxF "$applet" || die "BusyBox has no applet $applet"
		ln -s busybox "/rootfs/bin/$applet"
	done
}

main

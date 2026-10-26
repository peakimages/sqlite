#!/bin/sh
set -eu

USAGE="usage: sbom.sh IMAGE COMPONENT..., a component is apk|NAME|VENDOR:PRODUCT|PATH..., deb|NAME|LICENSE|VENDOR:PRODUCT|PATH... or generic|NAME|VERSION|LICENSE|URL|VENDOR:PRODUCT"
IMAGE="${1:-}"
REPOSITORY="${IMAGE%:*}"
OUTPUT_FILE="/rootfs/var/lib/db/sbom/${REPOSITORY##*/}-${IMAGE##*:}.syft.json"

die() {
	echo "sbom: $*" >&2
	exit 1
}

main() {
	[ "$#" -gt 1 ] || die "$USAGE"
	shift
	write_document "$@"
	verify_files
	echo "sbom: $OUTPUT_FILE lists $(jq -r '[.artifacts[] | "\(.name) \(.version)"] | join(", ")' "$OUTPUT_FILE")"
}

write_document() {
	mkdir -p "${OUTPUT_FILE%/*}"
	cat /lib/apk/db/installed /var/lib/dpkg/status 2> /dev/null | jq -Rsc --rawfile os_release /etc/os-release --arg usage "$USAGE" '
		([$os_release | split("\n")[] | capture("^(?<key>[A-Z_]+)=\"?(?<value>[^\"]*)")] | from_entries) as $os
		| [
			split("\n\n")[] | [split("\n")[] | capture("^(?<key>[^ :]+): ?(?<value>.*)$")] | from_entries
			| select(.Status | . == null or endswith(" installed"))
		] as $installed
		| def installed($key; $name): first($installed[] | select(.[$key] == $name)) // error("sbom: \($name) is not installed");
		def purl($path; $version; $qualifiers): "pkg:\($path)@\($version)?" + ([$qualifiers | to_entries[] | select(.value | length > 0) | "\(.key)=\(.value | @uri)"] | join("&"));
		def os_purl($type; $name; $version; $arch; $upstream): purl("\($type)/\($os.ID)/\($name)"; $version; { arch: $arch, distro: "\($os.ID)-\($os.VERSION_ID)", upstream: $upstream });
		def package($type; $name; $version; $license; $cpe; $purl): {
			name: $name,
			version: $version,
			type: $type,
			licenses: [{ value: $license, spdxExpression: $license, type: "declared" }],
			cpes: [{ cpe: "cpe:2.3:a:\($cpe):\($version | gsub("(?<c>[^A-Za-z0-9._-])"; "\\\(.c)")):*:*:*:*:*:*:*", source: "declared" }],
			purl: $purl
		};
		def apk($name; $cpe; $paths):
			installed("P"; $name)
			| package("apk"; .P; .V; .L; $cpe; os_purl("apk"; .P; .V; .A; if .o != .P then .o else "" end)) + {
				metadataType: "apk-db-entry",
				metadata: { package: .P, originPackage: .o, version: .V, architecture: .A, files: [$paths[] | { path: . }] }
			};
		def deb($name; $license; $cpe; $paths):
			installed("Package"; $name)
			| package("deb"; .Package; .Version; $license; $cpe; os_purl("deb"; .Package; .Version; .Architecture; .Source // "" | sub(" \\((?<version>.*)\\)$"; "@\(.version)"))) + {
				metadataType: "dpkg-db-entry",
				metadata: { package: .Package, source: (.Source // "" | sub(" .*"; "")), version: .Version, architecture: .Architecture, files: [$paths[] | { path: . }] }
			};
		def generic($name; $version; $license; $url; $cpe):
			package("binary"; $name; $version; $license; $cpe; purl("generic/\($name)"; $version; { download_url: $url }));
		{
			artifacts: [
				$ARGS.positional[] | split("|") | . as [$type, $name]
				| if $type == "apk" and length > 3 then apk($name; .[2]; .[3:])
				elif $type == "deb" and length > 4 then deb($name; .[2]; .[3]; .[4:])
				elif $type == "generic" and length == 6 then generic($name; .[2]; .[3]; .[4]; .[5])
				else error("sbom: \(join("|")) is not a component, \($usage)") end
			],
			schema: { version: "16.1.10", url: "https://raw.githubusercontent.com/anchore/syft/main/schema/json/schema-16.1.10.json" }
		}' --args "$@" > "$OUTPUT_FILE"
}

verify_files() {
	jq -r '.artifacts[].metadata.files[]?.path' "$OUTPUT_FILE" | while read -r path; do
		[ -f "/rootfs$path" ] || die "$path is not a file in /rootfs"
	done
}

main "$@"

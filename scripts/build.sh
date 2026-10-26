#!/usr/bin/env bash
set -euo pipefail

OPTION="$*"
IMAGE="${1:-peakimages/sqlite:local}"
PLATFORM="${PLATFORM:-}"

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' RESET=$'\033[0m'

ok() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
die() {
	printf '  %s✖%s %s\n' "$RED" "$RESET" "$*" >&2
	exit 1
}

cd "$(dirname "$0")/.."

main() {
	[[ "$OPTION" =~ ^([^-][^[:space:]]*)?$ ]] || die "'$OPTION' is not an option, expected an image or none"
	build
}

build() {
	local image_version
	[ -z "${CI:-}" ] || die "scripts/build.sh is for local builds, CI builds with docker/build-push-action"
	image_version="$(scripts/version.sh --build)"
	docker buildx build ${PLATFORM:+--platform "$PLATFORM"} --build-arg IMAGE_VERSION="$image_version" \
		--provenance mode=max --sbom true --load --tag "$IMAGE" src
	ok "$IMAGE is built for ${PLATFORM:-the platform of the Docker host} with image version $BOLD$image_version$RESET"
}

main

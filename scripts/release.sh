#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="$(mktemp -d)"

BOLD=$'\033[1m' DIM=$'\033[2m' GREEN=$'\033[32m' BLUE=$'\033[34m' RED=$'\033[31m' RESET=$'\033[0m'

heading() { printf '\n  %s%s%s\n' "$BOLD" "$*" "$RESET"; }
info() { printf '  %sℹ%s %s\n' "$BLUE" "$RESET" "$*"; }
ok() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
hint() { printf '  %-26s%s%s%s\n' "$1" "$DIM" "$2" "$RESET"; }
die() {
	printf '  %s✖%s %s\n' "$RED" "$RESET" "$*" >&2
	exit 1
}
confirm() {
	local answer
	printf '\n  %s [y/N] ' "$*"
	read -r answer
	[[ "$answer" =~ ^[Yy]$ ]]
}

cd "$(dirname "$0")/.."
trap 'rm -rf "$WORK_DIR"; tput cnorm 2> /dev/null || true' EXIT

main() {
	check_repository
	read_version
	select_bump
	heading "Releasing v$new_version"
	update_changelog
	update_dockerfile
	commit
	push
}

check_repository() {
	local branch ahead behind entries word
	heading "Checking the repository"
	git rev-parse --is-inside-work-tree > /dev/null 2>&1 || die "$PWD is not a git repository"
	branch="$(git rev-parse --abbrev-ref HEAD)"
	[ "$branch" = main ] || die "releases are made from main, the current branch is $branch"
	[ -z "$(git status --porcelain)" ] || die "the working tree is not clean, commit or stash first"
	git fetch --quiet origin || die "could not fetch origin"
	ahead="$(git rev-list --count origin/main..HEAD)"
	behind="$(git rev-list --count HEAD..origin/main)"
	[ "$ahead" = 0 ] || die "main is $ahead commit(s) ahead of origin/main, push first"
	[ "$behind" = 0 ] || die "main is $behind commit(s) behind origin/main, pull first"
	ok "main is clean and in sync with origin/main"
	entries="$(awk '/^## \[Unreleased\]$/ { inside = 1; next } /^## / { inside = 0 } inside && /^- /' CHANGELOG.md | wc -l | tr -d ' ')"
	[ "$entries" != 0 ] || die "CHANGELOG.md has no entries under ## [Unreleased], describe the changes first"
	word=entries
	[ "$entries" = 1 ] && word=entry
	ok "CHANGELOG.md has $BOLD$entries$RESET unreleased $word"
}

read_version() {
	current_version="$(sed -nE 's/^ARG IMAGE_VERSION=(.*)$/\1/p' src/Dockerfile)"
	[[ "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "IMAGE_VERSION in src/Dockerfile is '$current_version', expected major.minor.patch"
}

select_bump() {
	local major minor patch options choice
	IFS=. read -r major minor patch <<< "$current_version"
	options=("$major.$minor.$((patch + 1))" "$major.$((minor + 1)).0" "$((major + 1)).0.0")
	heading "Current version v$current_version, select the bump"
	choice="$(menu "patch  v${options[0]}" "minor  v${options[1]}" "major  v${options[2]}")"
	new_version="${options[$choice]}"
}

update_changelog() {
	local today
	today="$(date +%Y-%m-%d)"
	awk -v heading="## [v$new_version] - $today" '{ print } /^## \[Unreleased\]$/ { print ""; print heading }' CHANGELOG.md > "$WORK_DIR/CHANGELOG.md"
	cp "$WORK_DIR/CHANGELOG.md" CHANGELOG.md
	ok "CHANGELOG.md dates the unreleased entries as ${BOLD}v$new_version$RESET, $today"
}

update_dockerfile() {
	sed -E "s/^ARG IMAGE_VERSION=.*/ARG IMAGE_VERSION=$new_version/" src/Dockerfile > "$WORK_DIR/Dockerfile"
	cp "$WORK_DIR/Dockerfile" src/Dockerfile
	ok "src/Dockerfile sets IMAGE_VERSION $current_version → $BOLD$new_version$RESET"
}

commit() {
	git add src/Dockerfile CHANGELOG.md
	git commit --quiet -S --message "feat(release): bump image version to v$new_version"
	ok "signed commit $DIM$(git rev-parse --short HEAD)$RESET $(git log -1 --format=%s)"
}

push() {
	local tag
	tag="$(jq -r .version src/version.json)-v$new_version"
	if confirm "Push to origin/main?"; then
		git push --quiet origin main
		ok "pushed to origin/main, the tests run and then the release workflow publishes $BOLD$tag$RESET"
		heading "Next"
		hint "gh run watch" "follow the workflow run"
		hint "Releases on GitHub" "review the draft release once the workflow run is green and then publish it"
	else
		info "not pushed"
		heading "Next"
		hint "git push" "push the release commit later"
		hint "scripts/undo-release.sh" "undo the release commit"
	fi
}

menu() {
	local options=("$@") selected=0 key i
	tput civis 2> /dev/null || true
	while true; do
		for i in "${!options[@]}"; do
			if [ "$i" = "$selected" ]; then
				printf '  %s❯ %s%s\n' "$GREEN" "${options[$i]}" "$RESET" >&2
			else
				printf '  %s  %s%s\n' "$DIM" "${options[$i]}" "$RESET" >&2
			fi
		done
		IFS= read -rsn1 key
		if [ "$key" = $'\x1b' ]; then
			IFS= read -rsn2 key
			if [ "$key" = '[A' ] && [ "$selected" -gt 0 ]; then
				selected=$((selected - 1))
			elif [ "$key" = '[B' ] && [ "$selected" -lt $((${#options[@]} - 1)) ]; then
				selected=$((selected + 1))
			fi
		elif [ -z "$key" ]; then
			break
		fi
		printf '\033[%dA\033[J' "${#options[@]}" >&2
	done
	tput cnorm 2> /dev/null || true
	echo "$selected"
}

main

# Changelog

All notable changes to this project will be documented in this file. SQLite version bumps are not listed, every release tag names the SQLite version it ships.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v0.3.0] - 2026-11-12

### Security

- Moved the home of `nonroot` from `/var/lib/sqlite` to `/home/nonroot`, `sqlite3` runs the `.sqliterc` of the home on every start, and every user can write `/var/lib/sqlite`
  - `sqlite3` reads its startup file from `/home/nonroot/.sqliterc`, which only `nonroot` can write
  - The working directory stays `/var/lib/sqlite`

### Changed

- Alpine in the build stage from 3.24.3 to 3.24.4
- Image labels to one set that every image uses
  - `dev.peakimages.image` gains `distro`, `variant`, `flavor`, `shell` and `package-manager`
  - `dev.peakimages.image.upstream.version` replaces `dev.peakimages.sqlite.version`
  - `dev.peakimages.sqlite.extensions`, `dev.peakimages.tini.version` and `dev.peakimages.busybox.version` are removed, `README.md` lists the extensions and the SBOM the packages
  - `org.opencontainers.image.licenses` names the license of the image and of SQLite, and `base.name` is empty with an empty `base.digest` for an image built from `scratch`
- Vendor and authors labels from `peakimages` to `PeakImages`, the name as it is written everywhere but in a URL or an image name

### Fixed

- Health check failing with `database is locked` while an application writes, and making the writes of an application without a busy timeout fail
  - The health check reads every database with `immutable=1`, which takes no lock
  - When that read fails, it opens the database as before, with a busy timeout of 3 seconds
- Scanners listing the wrong packages and the wrong OS, `syft` found only `busybox 1.37.0`, `grype` reported two BusyBox CVEs Alpine has fixed and none of SQLite, and Trivy found nothing
  - `sqlite3` carries a package note and the image the apk package database records of tini and BusyBox, `syft` and `grype` list all three, Trivy all but SQLite
  - A scanner reports the image as Alpine, the release tini and BusyBox are taken from, instead of BusyBox or no OS, the same way Docker Hardened Images does
  - The SBOM attestation lists the same three packages as before, it was already correct, but a scanner does not read it and makes its own list from the image
  - The syft document in `/var/lib/db/sbom` that BuildKit made the SBOM attestation from is gone, BuildKit runs syft, which reads the package note and the apk package database natively
  - `syft` no longer needs the `--select-catalogers +sbom-cataloger` flag to read the custom SBOM in the syft JSON file, as its default list is now correct too

## [v0.2.0] - 2026-10-30

Older SQLite lines, prereleases and four more platforms, reproducible builds, a new release process, and databases that any uid can write.

### Breaking Changes

- Compressed the layers with zstd instead of gzip, pulling the image now needs Docker Engine 23.0 or later

### Security

- Hardened the image against a checkout with a permissive umask, the Dockerfile sets the mode of every file it copies from the repository, so no build can make `/usr`, `/usr/local` or `/usr/local/bin` writable for every user
- Published the images the tests ran against, every SQLite line is built once for every platform and tested, and a release publishes exactly these builds, not a second build
- Made release tags immutable
  - Docker Hub refuses to overwrite or delete a release tag such as `3.54.1-v0.2.0`
  - GitHub refuses to update, force-push or delete the git tag of a release
- Hardened the CI workflows
  - Every job gets the least permissions it needs, and every write permission states its reason
  - The Docker Hub credentials live in the `release` environment, which only the branches that release can use, with a token that can push but not delete
  - The tokens that delete images live in the `cleanup` environment, which only `main` can use and a maintainer approves for every run
  - `.github/workflows/actions.lock` locks every action and the actions it calls to a commit, and the lint job fails when the lockfile is stale
  - The binfmt image is pinned by tag and digest, as it runs privileged and installs the QEMU of every emulated build
  - The workflows allow only the events they use, so `pull_request_target`, `workflow_run` and comment events start no run
  - No run uses the GitHub Actions cache, a layer cache or a cached tool binary, so no run restores what another run wrote
  - jactionlint pedantic, which includes the audits of zizmor, lints the workflows and fails on every warning

### Added

- Shell options sqlite.org recommends for a full-featured shell: `.recover` and `.dbinfo`, the `sqlite_dbpage` and `sqlite_stmt` virtual tables, the `sqlite_offset()` function, comments in `EXPLAIN` output and `EXPLAIN` of statements that call functions the shell does not know
- Reproducible builds with the new `SOURCE_DATE_EPOCH` build argument, a rebuild of the same commit gives the same image digest per platform, and the `created` date of the image and its `org.opencontainers.image.created` label are the date of that commit
- Prereleases from `next` and the release branches, tagged like `3.54.1-v0.2.0-beta.1`, and the moving `preview` tag that points at the newest one
- Older SQLite lines such as `3.53` next to the newest, built with the same image version and tagged like `3.53.4-v0.2.0`, `3.53.4` and `3.53`
- Builds for `linux/arm/v6`, `linux/ppc64le`, `linux/s390x` and `linux/386`, eight platforms in total

### Changed

- `/var/lib/sqlite` from mode `0700` to `0777` and new databases to mode `0666`, which their `-wal` and `-shm` files take, so the application can run as any uid and not only as `65532` or root
- Name of the build argument `BUILD_DATE` to `CREATED`
- Build argument `IMAGE_VERSION` from optional to required, a build without it stops in the build stage
- Alpine in the build stage from 3.24.2 to 3.24.3

### Removed

- `SQLITE_UID` and `SQLITE_GID` build arguments, the user is always `65532:65532`

### Fixed

- Missing description and license on ghcr.io
  - The release index carries the labels of the image as annotations, where ghcr.io reads them for an image of several platforms
- SBOM attestation without usable entries for SQLite, tini and BusyBox
  - A syft document in `/var/lib/db/sbom` lists all three with their versions, licenses, package URLs and CPEs, a scratch image has no package database for the scanner to read
- `LICENSE` not matching the AGPL-3.0 text on gnu.org

### Maintenance

- Replaced the release process, `RELEASE.md` describes it
  - `release.json` keeps the image versions and `src/upstream.json` pins SQLite, one entry per line
  - Releases come from `main`, `next`, release branches such as `release/v0.3` and maintenance branches such as `v1.x` and `v0.1.x`
  - `scripts/release.sh` selects the stage and the version, it offers the versions the branch allows
  - `scripts/plan-version.sh` plans the image version, the releases and the moving tags, and reports what a push publishes
  - A push of `release.json` or `src/upstream.json` publishes the versions they set, unless they are published already
  - `latest`, `preview` and every prefix of a SQLite version move to their place among all published tags, so a release of an older line never moves a tag back
  - Every SQLite line is checked twice a day, with one pull request per bump, and a new SQLite release is verified against its release notes and its tagged check-in on sqlite.org
  - `main` is merged forward into the release branches and `next` after every release
  - Git tags and GitHub releases have a leading `v`, such as `v3.54.1-v0.2.0`, the image tags stay `3.54.1-v0.2.0`
- Added `scripts/build.sh` to build the image locally with the image version CI builds with, for the platform of the Docker host or the platforms `PLATFORM` names

## [v0.1.0] - 2026-09-23

Initial release.

### Added

- Minimal and hardened SQLite image on `scratch` with a static `sqlite3` shell, `tini` and BusyBox, running as the `nonroot` user `65532`
- Health check over every database
- `FTS3`, `FTS4`, `FTS5`, `R*Tree`, `Geopoly`, `JSON`, `math`, `dbstat` and `soundex` extensions
- Builds for `amd64`, `arm64`, `arm/v7` and `riscv64`

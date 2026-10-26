# Changelog

All notable changes to this project will be documented in this file. SQLite version bumps are not listed, every release tag names the SQLite version it ships.

## [Unreleased]

### Breaking Changes

- Compress the layers with zstd instead of gzip, zstd is faster, more modern and compresses better than gzip, pulling needs Docker Engine 23.0 or later

### Added

- Add `.recover` and `.dbinfo` to the shell and the `sqlite_dbpage` and `sqlite_stmt` virtual tables, the shell is built with the options sqlite.org recommends for a full-featured shell
- Build reproducibly, a rebuild of the same commit gives the same image digest per platform, and the `created` date of the image and its `org.opencontainers.image.created` label are the date of that commit
- Publish prereleases from `next` and the release branches, tagged like `3.54.1-v0.2.0-beta.1`, and the moving `preview` tag
- Publish older SQLite lines such as `3.53` next to the newest, built with the same image version and tagged like `3.53.4-v0.2.0`, `3.53.4` and `3.53`

### Changed

- Let any uid write the databases, `/var/lib/sqlite` is `0777` and the entrypoint creates databases with mode `0666`, which their `-wal` and `-shm` files take, so the application can run as any user and not only as `65532` or root
- Replace the release process, `RELEASE.md` describes it
  - Keep the image versions in `release.json`, `stable.image` for `main` and the maintenance branches and `preview.image` for `next` and the release branches
  - Pin SQLite in `src/upstream.json`, one entry per line, instead of `src/version.json`
  - Release from `main`, `next`, release branches such as `release/v0.3` and maintenance branches such as `v1.x` and `v0.1.x`
  - Select the stage and the version with `scripts/release.sh`, which offers the versions the branch allows and preselects the bump the commits need
  - Decide the image version, the releases and the moving tags with `scripts/version.sh`, which also reports what a push publishes
  - Publish every release a push of `release.json` or `src/upstream.json` names and whose tag does not exist yet, never as a draft
  - Move `latest`, `preview` and every prefix of a SQLite version to their place among all published tags, so a release of an older line never moves a tag back
  - Check every SQLite line of `main`, the maintenance branches and the major release branches twice a day and open one pull request per bump, which supersedes the older ones
  - Verify a new SQLite release against its release notes and its tagged check-in on sqlite.org
  - Merge `main` forward into `next` and the release branches twice a day and after every release
- Rework the CI workflows for the new release process
  - Split the build, test and release workflows, the release workflow calls the build workflow and the build workflow calls the tests
  - Build every SQLite line for every platform once, test those builds and publish exactly them, not a second build
  - Write the notes of the first release of an image version from `CHANGELOG.md`, later releases name the SQLite update
  - Mark the GitHub release that `latest` points at as the latest release
- Harden the CI workflows
  - Grant every job the least permissions it needs and state the reason for every write permission
  - Keep the Docker Hub credentials in the `release` environment
  - Run without the GitHub Actions cache, layer caches and cached tool binaries, so no run restores what another run wrote
  - Run every step with bash, so a failing command in a pipe fails the step
  - Queue release runs instead of cancelling them, so no two runs publish or move tags at the same time
  - Lint the workflows with jactionlint pedantic, which includes the audits of zizmor, and fail on every warning
- Remove the `SQLITE_UID` and `SQLITE_GID` build arguments, the user is `65532:65532`
- Rename the build argument `BUILD_DATE` to `CREATED`, add `SOURCE_DATE_EPOCH` and require `IMAGE_VERSION`
- Bump Alpine in the build stage from 3.24.2 to 3.24.3

### Fixed

- List SQLite, tini and BusyBox in the SBOM attestation with their versions, licenses, package URLs and CPEs, from an SBOM document in `/var/lib/db/sbom` that takes the place of the package database a scratch image lacks
- Match `LICENSE` to the AGPL-3.0 text on gnu.org

### Refactored

- Name the final stage of the Dockerfile `final`

### Maintenance

- Add `scripts/build.sh` to build the image locally with the image version CI builds with, for the platform of the Docker host or the platforms `PLATFORM` names
- Run docker build checks in `scripts/lint.sh` and stop at the first failed check
- Stop every script on arguments it does not take
- Indent JSON with tabs and format Markdown with prettier
- Bump `actions/download-artifact` to v8.0.2, `actions/upload-artifact` to v7.0.2 and `docker/login-action` to v4.7.0
- Document the release process in `RELEASE.md`
- Describe the image in `README.md` as a central home for SQLite databases, explain that the application keeps its own SQLite engine, add copying the static `sqlite3` shell into other images and drop the uid `65532` note
- Add reproducible builds, PIE, detached runs and SQLite updates to `docs/comparison.md` and explain the UPX packing of `grepular/sqlite3`
- Put the scope first in `SECURITY.md`

## [v0.1.0] - 2026-09-23

### Added

- Initial release, a minimal and hardened SQLite image on `scratch` with a static `sqlite3` shell, `tini` and BusyBox, `nonroot` user `65532`, a health check over every database, the `FTS3`, `FTS4`, `FTS5`, `R*Tree`, `Geopoly`, `JSON`, `math`, `dbstat` and `soundex` extensions and builds for `amd64`, `arm64`, `arm/v7` and `riscv64`

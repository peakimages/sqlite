# Changelog

All notable changes to this project will be documented in this file. SQLite version bumps are not listed, every release tag names the SQLite version it ships.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Breaking Changes

- Compress the layers with zstd instead of gzip, zstd is faster, more modern and compresses better than gzip, pulling needs Docker Engine 23.0 or later

### Security

- Harden the image against a checkout with a permissive umask, every file the build copies from the repository gets its mode from the Dockerfile, so no build can make `/usr`, `/usr/local` or `/usr/local/bin` writable for every user.
- Warn in `README.md` that a bind mount opens the databases to every user on the host who can reach the directory, and show how to close it
- Make release tags immutable
  - Refuse to overwrite or delete a release tag such as `3.54.1-v0.2.0` on Docker Hub by using the ag mutability setting on docker hub with a strict patter.
  - Refuse to updated, force push or delete the git tag of a release by using tag protection rule on GitHub
- Refuse to delete or force-push `main`, `next`, release and maintenance branches by using branch protection rules on GitHub
- Harden the CI workflows
  - Grant every job the least permissions it needs and state the reason for every write permission
  - Keep the Docker Hub credentials in the `release` environment, which only the branches that release can use, with a token that can push but not delete
  - Keep the tokens that delete images in the `cleanup` environment, which only `main` can use and a maintainer approves for every run
  - Lock every action and the actions it calls to a commit in `.github/workflows/actions.lock`, name actions by their release tag, and fail the lint job when the lockfile is stale
  - Pin the binfmt image by tag and digest, it runs privileged and installs the QEMU of every emulated build
  - Allow the workflows only the events they use, so `pull_request_target`, `workflow_run` and comment events start no run
  - Run without the GitHub Actions cache, layer caches and cached tool binaries, so no run restores what another run wrote
  - Lint the workflows with jactionlint pedantic, which includes the audits of zizmor, and fail on every warning

### Added

- Add the shell options sqlite.org recommends for a full-featured shell: `.recover` and `.dbinfo`, the `sqlite_dbpage` and `sqlite_stmt` virtual tables, the `sqlite_offset()` function, comments in `EXPLAIN` output and `EXPLAIN` of statements that call functions the shell does not know
- Build reproducibly, a rebuild of the same commit gives the same image digest per platform, and the `created` date of the image and its `org.opencontainers.image.created` label are the date of that commit
- Publish prereleases from `next` and the release branches, tagged like `3.54.1-v0.2.0-beta.1`, and the moving `preview` tag
- Publish older SQLite lines such as `3.53` next to the newest, built with the same image version and tagged like `3.53.4-v0.2.0`, `3.53.4` and `3.53`
- Builds for `linux/arm/v6`, `linux/ppc64le`, `linux/s390x` and `linux/386`, eight platforms in total
- Publish the image of every pull request from a branch of this repository as `ghcr.io/peakimages/sqlite:pr-<number>`, so a change can be tried before it is merged

### Changed

- Let any uid write the databases, `/var/lib/sqlite` is `0777` and the entrypoint creates databases with mode `0666`, which their `-wal` and `-shm` files take, so the application can run as any user and not only as `65532` or root
- Replace the release process, `RELEASE.md` describes it
  - Keep the image versions in `release.json`, `stable.image` for `main` and the maintenance branches and `preview.image` for `next` and the release branches
  - Pin SQLite in `src/upstream.json`, one entry per line, instead of `src/version.json`
  - Release from `main`, `next`, release branches such as `release/v0.3` and maintenance branches such as `v1.x` and `v0.1.x`
  - Select the stage and the version with `scripts/release.sh`, which offers the versions the branch allows and preselects the bump the commits need
  - Publish nothing while `release.json` sets `0.0.0`, the version a new repository starts with, `scripts/release.sh` offers `0.1.0` or `1.0.0` as its first release
  - Plan the image version, the releases and the moving tags with `scripts/plan-version.sh`, which also reports what a push publishes
  - Publish every release a push of `release.json` or `src/upstream.json` names and whose tag does not exist yet, never as a draft
  - Move `latest`, `preview` and every prefix of a SQLite version to their place among all published tags, so a release of an older line never moves a tag back
  - Check every SQLite line of `main`, the maintenance branches and the major release branches twice a day and open one pull request per bump, which supersedes the older ones
  - Verify a new SQLite release against its release notes and its tagged check-in on sqlite.org
  - Merge `main` forward into `next` and the release branches twice a day and after every release
  - Tag releases in git and on GitHub with a leading `v`, `v3.54.1-v0.2.0`, the image tags stay `3.54.1-v0.2.0`, and rename the tags and releases of the earlier versions to match
- Rework the CI workflows for the new release process
  - Split the build, test and release workflows, the release workflow calls the build workflow and the build workflow calls the tests
  - Build every SQLite line for every platform once, test those builds and publish exactly them, not a second build
  - Write the notes of the first release of an image version from `CHANGELOG.md`, later releases name the SQLite update
  - Mark the GitHub release that `latest` points at as the latest release
  - Run every step with bash, so a failing command in a pipe fails the step
  - Queue release runs instead of cancelling them, so no two runs publish or move tags at the same time
- Remove the `SQLITE_UID` and `SQLITE_GID` build arguments, the user is `65532:65532`
- Rename the build argument `BUILD_DATE` to `CREATED`, add `SOURCE_DATE_EPOCH` and require `IMAGE_VERSION`
- Bump Alpine in the build stage from 3.24.2 to 3.24.3

### Fixed

- Push nothing but the release index, its images and their attestations, the old release workflow pushed every platform as an index of its own by digest, which stayed behind untagged and unused next to the release index on ghcr.io and docker.io
- Copy the labels of the image to the annotations of the release index, ghcr.io reads the description and the license of an image of several platforms from there and showed neither
- List SQLite, tini and BusyBox in the SBOM attestation with their versions, licenses, package URLs and CPEs, from an SBOM document in `/var/lib/db/sbom` that takes the place of the package database a scratch image lacks
- Match `LICENSE` to the AGPL-3.0 text on gnu.org

### Refactored

- Name the final stage of the Dockerfile `final`

### Maintenance

- Add `scripts/clean-manifests.sh` and a monthly workflow that delete the manifests no tag needs from ghcr.io and docker.io, such as the untagged images the old release workflow left behind and the images of closed pull requests, and keep every release and every image a tag points at
- Add `scripts/size.sh` to measure the compressed and the on-disk size of every platform, and comment the size change of every pull request compared with the latest release
- Add `scripts/build.sh` to build the image locally with the image version CI builds with, for the platform of the Docker host or the platforms `PLATFORM` names
- Run docker build checks in `scripts/lint.sh` and stop at the first failed check
- Stop every script on arguments it does not take
- Indent JSON with tabs and format Markdown with prettier
- Bump `actions/download-artifact` to v8.0.2, `actions/upload-artifact` to v7.0.2 and `docker/login-action` to v4.7.0
- Document the release process in `RELEASE.md`
- Describe the image in `README.md` as a central home for SQLite databases, explain that the application keeps its own SQLite engine, add copying the static `sqlite3` shell into other images and drop the uid `65532` note
- Add reproducible builds, PIE, detached runs and SQLite updates to `docs/comparison.md` and explain the UPX packing of `grepular/sqlite3`
- Put the scope first in `SECURITY.md`
- Add a Why section to the pull request template

## [v0.1.0] - 2026-09-23

### Added

- Initial release, a minimal and hardened SQLite image on `scratch` with a static `sqlite3` shell, `tini` and BusyBox, `nonroot` user `65532`, a health check over every database, the `FTS3`, `FTS4`, `FTS5`, `R*Tree`, `Geopoly`, `JSON`, `math`, `dbstat` and `soundex` extensions and builds for `amd64`, `arm64`, `arm/v7` and `riscv64`

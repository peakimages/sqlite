# SQLite

[![Release](https://img.shields.io/github/actions/workflow/status/peakimages/sqlite/release.yaml?branch=main&label=release)](https://github.com/peakimages/sqlite/actions/workflows/release.yaml)
[![SQLite](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fpeakimages%2Fsqlite%2Fmain%2Fsrc%2Fupstream.json&query=%24.sqlite.latest.version&label=sqlite)](https://github.com/peakimages/sqlite/releases)
[![License](https://img.shields.io/github/license/peakimages/sqlite)](LICENSE)
[![Docker pulls](https://img.shields.io/docker/pulls/peakimages/sqlite)](https://hub.docker.com/r/peakimages/sqlite)
[![Image size](https://img.shields.io/docker/image-size/peakimages/sqlite/latest?arch=amd64)](https://hub.docker.com/r/peakimages/sqlite)

## Introduction

A central home for one or more SQLite databases. One minimal and hardened container creates every database you name, health checks them and brings the `sqlite3` shell for backups, restores and maintenance. Made for [Coolify](https://coolify.io?ref=peakimages.dev) and any other container host.

> [!IMPORTANT]
> `peakimages/sqlite` is currently **v0** and subject to breaking changes prior to `v1.0.0`. Pin to a specific version like `peakimages/sqlite:3.54.1-v0.2.0` to avoid breaking changes.

### What Makes This Image Different?

SQLite has no server and the database is just a file. Application images rarely ship the `sqlite3` shell to run backup or vacuum commands, so this image gives the database file a minimal and secure home with the shell and the extensions built in.

- ✅ Secure by Default: Runs as unprivileged user `65532` on `scratch`, no package manager, read-only root filesystem supported
- ✅ Faster and Smaller: Purposely built with the [compile-time options sqlite.org recommends](https://sqlite.org/compile.html#recommended_compile_time_options) to save CPU cycles and memory, and to turn off legacy misfeatures
- ✅ Zero Config Required: Production-ready defaults, customizable with environment variables
- ✅ Multi-Database Support: One container creates and health checks every database you name
- ✅ Verified Source: Size, SHA3-256 and source id of the official amalgamation are checked before each compilation
- ✅ Batteries Included: `FTS3`, `FTS4`, `FTS5`, `R*Tree`, `Geopoly`, `math`, `dbstat`, `dbpage`, `stmt` and `soundex` SQLite extensions
- ✅ Modern Architecture: Native health checks, `tini` init, OCI labels, reproducible builds, provenance and SBOM attestations
- ✅ Always Current: sqlite.org is checked twice a day and new SQLite releases become new images
- ✅ Multi-Architecture: Builds for `linux/amd64`, `linux/arm64`, `linux/arm/v7` and `linux/riscv64`
- ✅ Tested: Every release is tested on all four platforms before it is published

## Comparison

To see a comparison of this image with other popular SQLite Docker images, see [docs/comparison.md](docs/comparison.md).

## Getting Started

SQLite is not a server and the database is just a file. The application reads and writes it with the SQLite engine it bundles, such as `pdo_sqlite` for PHP or `rusqlite` for Rust, so the SQLite version and extensions of that engine apply, not the ones of this image. This container shares the volume with the application and looks after the files: it creates and configures them, health checks them and brings the `sqlite3` shell for backups, restores and maintenance.

### Docker

Start the container with a named volume for the default database:

```sh
docker run -d --name sqlite -v sqlite-data:/var/lib/sqlite peakimages/sqlite
```

### Docker Compose

Add the SQLite container next to the application that needs a SQLite database, both mounting the same volume:

```yaml
services:
  sqlite:
    image: peakimages/sqlite:3.54.1-v0.2.0
    environment:
      SQLITE_DATABASES: app.sqlite, jobs.sqlite
    volumes:
      - sqlite-data:/var/lib/sqlite

  app:
    image: your-app
    depends_on:
      sqlite:
        condition: service_healthy
    volumes:
      - sqlite-data:/var/lib/sqlite
    environment:
      DATABASE_URL: sqlite:///var/lib/sqlite/app.sqlite

volumes:
  sqlite-data:
```

### Shell for Other Images

`sqlite3` is a static binary without dependencies. You can copy it into any image with a single line, and it works on `scratch`, distroless, Alpine, Debian and more, for backups, restores and maintenance without a package manager:

```dockerfile
COPY --from=peakimages/sqlite:3.54.1-v0.2.0 /usr/local/bin/sqlite3 /usr/local/bin/sqlite3
```

## Available Image Variations

For now there is just one image variation. All tags follow this pattern:

```sh
peakimages/sqlite:{{sqlite-version}}-v{{image-version}}
```

| Variation | Best For                                                            | Example                                                      |
| --------- | ------------------------------------------------------------------- | ------------------------------------------------------------ |
| default   | Every SQLite deployment, from a Coolify service to a Kubernetes pod | `peakimages/sqlite:3.54.1-v0.2.0` `peakimages/sqlite:3.54.1` |

### Tags

| Tag                   | Meaning                                                                       |
| --------------------- | ----------------------------------------------------------------------------- |
| `3.54.1-v0.2.0`       | Immutable: SQLite 3.54.1 built as image v0.2.0, never rebuilt                 |
| `3.54.1`, `3.54`, `3` | Newest release of that SQLite patch, minor or major version                   |
| `latest`              | Newest release                                                                |
| `preview`             | Newest prerelease, like `3.54.1-v0.3.0-beta.1`, until its release replaces it |

### Registries

| 📦 Registry                                                                             | 🐳 Image                                                                                                                    |
| --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| [Docker Hub](https://hub.docker.com/r/peakimages/sqlite)                                | ![peakimages/sqlite](https://img.shields.io/github/v/release/peakimages/sqlite?label=peakimages%2Fsqlite)                   |
| [GitHub Container Registry](https://github.com/peakimages/sqlite/pkgs/container/sqlite) | ![ghcr.io/peakimages/sqlite](https://img.shields.io/github/v/release/peakimages/sqlite?label=ghcr.io%2Fpeakimages%2Fsqlite) |

## Configuration

The defaults are set in the image, override them with `-e` or the `environment` section of a docker compose service.

| Variable              | Default           | Meaning                                                                                                                   |
| --------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `SQLITE_DATABASES`    | `database.sqlite` | Databases in `/var/lib/sqlite`, a comma-separated list. Missing files are created on start, existing ones are left alone  |
| `SQLITE_JOURNAL_MODE` | `WAL`             | Journal mode of a new database: `WAL`, `DELETE`, `TRUNCATE`, `PERSIST`, `MEMORY` or `OFF`. Only `WAL` stays in the file   |
| `SQLITE_AUTO_VACUUM`  | `NONE`            | `NONE`, `FULL` or `INCREMENTAL` for a new database. **Fixed once the first table exists**                                 |
| `SQLITE_PAGE_SIZE`    | `4096`            | Page size of a new database, a power of two from `512` to `65536`. **Fixed once the database has content**                |
| `SQLITE_TMPDIR`       | unset             | Directory for the temporary files of sorts and vacuums. Default `/tmp`, or the data directory when `/tmp` is not writable |

## Releases

Every SQLite release becomes a new version of the image. A check for new SQLite versions runs twice a day.

The image version follows semantic versioning independently of SQLite. Changes to the image are listed in [CHANGELOG.md](CHANGELOG.md).

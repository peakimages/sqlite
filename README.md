# SQLite

[![Tests](https://img.shields.io/github/actions/workflow/status/peakimages/sqlite/tests.yaml?branch=main&label=tests)](https://github.com/peakimages/sqlite/actions/workflows/tests.yaml)
[![SQLite](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fpeakimages%2Fsqlite%2Fmain%2Fsrc%2Fversion.json&query=%24.version&label=sqlite)](https://github.com/peakimages/sqlite/releases)
[![License](https://img.shields.io/github/license/peakimages/sqlite)](LICENSE)
[![Docker pulls](https://img.shields.io/docker/pulls/peakimages/sqlite)](https://hub.docker.com/r/peakimages/sqlite)
[![Image size](https://img.shields.io/docker/image-size/peakimages/sqlite/latest)](https://hub.docker.com/r/peakimages/sqlite)

## Introduction

Minimal, production-ready, hardened and secure SQLite Docker image. Made for SQLite database deployments on [Coolify](https://coolify.io) and any other container host.

> [!IMPORTANT]
> `peakimages/sqlite` is currently **v0** and subject to breaking changes prior to `v1.0.0`. Pin to a specific version like `peakimages/sqlite:3.53.4-v0.1.0` to avoid breaking changes.

### What Makes This Image Different?

SQLite has no server and the database is just a file. Application images rarely ship the `sqlite3` shell to run backup or vacuum commands, so this image gives the database file a minimal and secure home with the shell and the extensions built in.

- ✅ Secure by Default: Runs as unprivileged user `65532` on `scratch`, no package manager, read-only root filesystem supported
- ✅ Faster and Smaller: Purposely built with the [compile-time options sqlite.org recommends](https://sqlite.org/compile.html#recommended_compile_time_options) to save CPU cycles and memory, and to turn off legacy misfeatures
- ✅ Zero Config Required: Production-ready defaults, customizable with environment variables
- ✅ Multi-Database Support: One container creates and health checks every database you name
- ✅ Verified Source: Size, SHA3-256 and source id of the official amalgamation are checked before each compilation
- ✅ Batteries Included: `FTS3`, `FTS4`, `FTS5`, `R*Tree`, `Geopoly`, `JSON`, `math`, `dbstat` and `soundex` SQLite extensions
- ✅ Modern Architecture: Native health checks, `tini` init, OCI labels, provenance and SBOM attestations
- ✅ Always Current: sqlite.org is checked daily and every new SQLite release becomes a new image
- ✅ Multi-Architecture: Builds for `linux/amd64`, `linux/arm64`, `linux/arm/v7` and `linux/riscv64`
- ✅ Tested: Every release is tested on all four platforms before it is published

## Comparison

To see a comparison of this image with other popular SQLite Docker images, see [docs/comparison.md](docs/comparison.md).

## Getting Started

### Docker

Start the container with a named volume for the default database:

```sh
docker run -d --name sqlite -v sqlite-data:/var/lib/sqlite peakimages/sqlite
```

### Docker Compose

Add the SQLite container next to the application that needs a SQLite database, both mounting the same volume:

> [!IMPORTANT]
> The application must run as uid `65532`, the `nonroot` user of distroless images, or as root to write to the database.

```yaml
services:
  sqlite:
    image: peakimages/sqlite:3.53.4-v0.1.0
    environment:
      SQLITE_DATABASES: app.sqlite, jobs.sqlite
    volumes:
      - sqlite-data:/var/lib/sqlite

  app:
    image: your-app
    user: "65532:65532"
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

## Available Image Variations

For now there is just one image variation. All tags follow this pattern:

```sh
peakimages/sqlite:{{sqlite-version}}-v{{image-version}}
```

| Variation | Best For                                                            | Example                                                      |
| --------- | ------------------------------------------------------------------- | ------------------------------------------------------------ |
| default   | Every SQLite deployment, from a Coolify service to a Kubernetes pod | `peakimages/sqlite:3.53.4-v0.1.0` `peakimages/sqlite:3.53.4` |

### Tags

| Tag                   | Meaning                                                       |
| --------------------- | ------------------------------------------------------------- |
| `3.53.4-v0.1.0`       | Immutable: SQLite 3.53.4 built as image v0.1.0, never rebuilt |
| `3.53.4`, `3.53`, `3` | Newest build of that SQLite patch, minor or major version     |
| `latest`              | Newest build                                                  |

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

Every SQLite release becomes a new version of the image. A check for new SQLite versions is run daily.

The image version follows semantic versioning independently of SQLite. Changes to the image are listed in [CHANGELOG.md](CHANGELOG.md).

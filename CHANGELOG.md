# Changelog

All notable changes to this project will be documented in this file. SQLite version bumps are not listed, every release tag names the SQLite version it ships.

## [Unreleased]

### Added

- Initial release: minimal, production-ready, hardened and secure SQLite Docker image. Static `sqlite3` shell built with the compile-time options sqlite.org recommends, `tini` and a static BusyBox on `scratch`, `nonroot` user `65532`, health check over every database, `FTS3`, `FTS4`, `FTS5`, `R*Tree`, `Geopoly`, `JSON`, `math`, `dbstat` and `soundex` extensions, built for `linux/amd64`, `linux/arm64`, `linux/arm/v7` and `linux/riscv64`

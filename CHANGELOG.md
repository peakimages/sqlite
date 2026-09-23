# Changelog

All notable changes to this project will be documented in this file. SQLite version bumps are not listed, every release tag names the SQLite version it ships.

## [Unreleased]

### Added

- Initial release, a minimal and hardened SQLite image on `scratch` with a static `sqlite3` shell, `tini` and BusyBox, `nonroot` user `65532`, a health check over every database, the `FTS3`, `FTS4`, `FTS5`, `R*Tree`, `Geopoly`, `JSON`, `math`, `dbstat` and `soundex` extensions and builds for `amd64`, `arm64`, `arm/v7` and `riscv64`

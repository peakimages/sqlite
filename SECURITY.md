# Security

This page outlines our support policy and how to report vulnerabilities.

## Support Policy

Below you can find the support status for different versions of the image. The image version is the `v` part of an image tag, `peakimages/sqlite:3.53.4-v0.1.0` is image version `v0.1.0`.

| Version | Supported          | Support Status     |
| ------- | ------------------ | ------------------ |
| **1.x** | :white_check_mark: | Unreleased         |
| **0.x** | :white_check_mark: | Active Development |

Immutable tags such as `3.53.4-v0.1.0` are never rebuilt. A fix ships as a new image version, and the floating tags `3.53.4`, `3.53`, `3` and `latest` move to it. Deployments that pin an immutable tag receive fixes by moving to the newer tag.

### Scope

- **This repository** builds the image: the Dockerfile and its compile-time options, the entrypoint and health check scripts, the root filesystem and the workflows that test and publish. Report vulnerabilities in these here.
- **SQLite itself** is developed at [sqlite.org](https://sqlite.org). Report vulnerabilities in SQLite to the SQLite team, see [sqlite.org/cves.html](https://sqlite.org/cves.html). Every new SQLite release becomes a new image, usually within a day.
- **BusyBox and tini** come from pinned Alpine packages. Alpine's fixes reach the image with the next release.

## Reporting a Vulnerability

If you find a security vulnerability in a currently supported version, please follow these steps:

1. **DO NOT** disclose the vulnerability publicly.
2. Report it via [GitHub Security Advisories](https://github.com/peakimages/sqlite/security/advisories/new).
3. Include in your report:
    - **Explanation:** Detailed explanation of the vulnerability.
    - **Affected Versions:** Which image tags are affected.
    - **Reproduction:** Clear steps to reproduce the vulnerability.
    - **Impact:** Assessment of the potential impact of the vulnerability.

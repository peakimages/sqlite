# Security

This page outlines what is in scope, our support policy and how to report vulnerabilities.

## Scope

Report a vulnerability to the project that maintains the affected code:

- **The image** is built in this repository: the Dockerfile and its compile-time options, the entrypoint and health check scripts, the root filesystem and the workflows that test and publish it. Report it here, see [Reporting a Vulnerability](#reporting-a-vulnerability).
- **SQLite** is maintained at [sqlite.org](https://sqlite.org). Report it to the SQLite team, see [sqlite.org/cves.html](https://sqlite.org/cves.html). Every SQLite release becomes a new image, usually within a day.
- **BusyBox and tini** come from pinned Alpine packages. Report it to Alpine or the upstream project, the fix reaches the image with its next release.

## Support Policy

Below you can find the support status for different versions of the image. The image version is the `v` part of an image tag, `peakimages/sqlite:3.54.1-v0.2.0` is image version `v0.2.0`.

| Version | Supported          | Support Status     |
| ------- | ------------------ | ------------------ |
| **1.x** | :white_check_mark: | Unreleased         |
| **0.x** | :white_check_mark: | Active Development |

Immutable tags such as `3.54.1-v0.2.0` are never rebuilt. A fix ships as a new image version, and the floating tags `3.54.1`, `3.54`, `3` and `latest` move to it. Deployments that pin an immutable tag receive fixes by moving to the newer tag.

## Reporting a Vulnerability

If you find a security vulnerability in a currently supported version, please follow these steps:

1. **DO NOT** disclose the vulnerability publicly.
2. Report it via [GitHub Security Advisories](https://github.com/peakimages/sqlite/security/advisories/new).
3. Include in your report:
   - **Explanation:** Detailed explanation of the vulnerability.
   - **Affected Versions:** Which image tags are affected.
   - **Reproduction:** Clear steps to reproduce the vulnerability.
   - **Impact:** Assessment of the potential impact of the vulnerability.

---
type: changed
---
Image labels to one set that every image uses

- `dev.peakimages.image` gains `distro`, `variant`, `flavor`, `shell` and `package-manager`
- `dev.peakimages.image.upstream.version` replaces `dev.peakimages.sqlite.version`
- `dev.peakimages.sqlite.extensions`, `dev.peakimages.tini.version` and `dev.peakimages.busybox.version` are removed, `README.md` lists the extensions and the SBOM the packages
- `org.opencontainers.image.licenses` names the license of the image and of SQLite, and `base.name` is empty with an empty `base.digest` for an image built from `scratch`

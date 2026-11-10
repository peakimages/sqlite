---
type: fixed
---
Scanners listing the wrong packages and the wrong OS, `syft` found only `busybox 1.37.0`, `grype` reported two BusyBox CVEs Alpine has fixed and none of SQLite, and Trivy found nothing

- `sqlite3` carries a package note and the image the apk package database records of tini and BusyBox, `syft` and `grype` list all three, Trivy all but SQLite
- A scanner reports the image as Alpine, the release tini and BusyBox are taken from, instead of BusyBox or no OS, the same way Docker Hardened Images does
- The SBOM attestation lists the same three packages as before, it was already correct, but a scanner does not read it and makes its own list from the image
- The syft document in `/var/lib/db/sbom` that BuildKit made the SBOM attestation from is gone, BuildKit runs syft, which reads the package note and the apk package database natively
- `syft` no longer needs the `--select-catalogers +sbom-cataloger` flag to read the custom SBOM in the syft JSON file, as its default list is now correct too

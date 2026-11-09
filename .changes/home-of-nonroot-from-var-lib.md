---
type: changed
---
Home of `nonroot` from `/var/lib/sqlite` to `/home/nonroot`, so `.sqlite_history` and whatever else a program writes under `HOME` stay out of the data directory

- The working directory stays `/var/lib/sqlite`, where the databases are

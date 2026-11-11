---
type: security
---
Moved the home of `nonroot` from `/var/lib/sqlite` to `/home/nonroot`, `sqlite3` runs the `.sqliterc` of the home on every start, and every user can write `/var/lib/sqlite`

- `sqlite3` reads its startup file from `/home/nonroot/.sqliterc`, which only `nonroot` can write
- The working directory stays `/var/lib/sqlite`

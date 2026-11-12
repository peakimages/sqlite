---
type: fixed
---
Health check failing with `database is locked` while an application writes, and making the writes of an application without a busy timeout fail

- The health check reads every database with `immutable=1`, which takes no lock
- When that read fails, it opens the database as before, with a busy timeout of 3 seconds

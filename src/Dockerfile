# syntax=docker/dockerfile:1

# Set by scripts/check-upstream.sh
ARG SQLITE_VERSION=3.53.4
# Set by scripts/release.sh
ARG IMAGE_VERSION=0.0.0

# Build dependencies
# https://hub.docker.com/_/alpine/tags?name=3.24.2
ARG BASE_IMAGE=alpine:3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6
# https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/tini-static
ARG TINI_VERSION=0.19.0-r3
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/busybox-static
ARG BUSYBOX_VERSION=1.37.0-r31

# Runtime user, nonroot 65532 like in distroless images
ARG SQLITE_UID=65532
ARG SQLITE_GID=65532

# ARGs set by the release workflow
ARG BUILD_DATE
ARG GIT_SHA

FROM ${BASE_IMAGE} AS build

ARG SQLITE_VERSION
ARG TINI_VERSION
ARG BUSYBOX_VERSION
ARG SQLITE_UID
ARG SQLITE_GID

# curl, jq and openssl are only used during the build stage, so they are not pinned to a specific version
# hadolint ignore=DL3018
RUN apk add --no-cache build-base curl jq openssl tini-static=${TINI_VERSION} busybox-static=${BUSYBOX_VERSION}

WORKDIR /src
COPY version.json verify.sh ./
RUN curl --proto '=https' --tlsv1.2 -sSf --retry 3 -o sqlite.zip "$(jq -r .url version.json)" \
    && sh verify.sh

# Compile SQLite and the sqlite3 shell into one static binary using recommended compile time options: https://sqlite.org/compile.html#recommended_compile_time_options
WORKDIR /src/sqlite
RUN gcc -static-pie -fPIE -Os \
        -ffunction-sections -fdata-sections -Wl,--gc-sections \
        -fstack-protector-strong -D_FORTIFY_SOURCE=2 \
        -Wl,-z,noexecstack -Wl,-z,relro -Wl,-z,now \
        -DSQLITE_THREADSAFE=0 \
        -DSQLITE_DQS=0 \
        -DSQLITE_DEFAULT_MEMSTATUS=0 \
        -DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1 \
        -DSQLITE_LIKE_DOESNT_MATCH_BLOBS \
        -DSQLITE_MAX_EXPR_DEPTH=0 \
        -DSQLITE_OMIT_DEPRECATED \
        -DSQLITE_OMIT_LOAD_EXTENSION \
        -DSQLITE_OMIT_PROGRESS_CALLBACK \
        -DSQLITE_OMIT_SHARED_CACHE \
        -DSQLITE_USE_ALLOCA \
        -DSQLITE_STRICT_SUBTYPE=1 \
        -DSQLITE_ENABLE_FTS3 \
        -DSQLITE_ENABLE_FTS3_PARENTHESIS \
        -DSQLITE_ENABLE_FTS4 \
        -DSQLITE_ENABLE_FTS5 \
        -DSQLITE_ENABLE_RTREE \
        -DSQLITE_ENABLE_GEOPOLY \
        -DSQLITE_ENABLE_MATH_FUNCTIONS \
        -DSQLITE_ENABLE_DBSTAT_VTAB \
        -DSQLITE_SOUNDEX \
        -DHAVE_USLEEP=1 \
        -DHAVE_FDATASYNC=1 \
        -DHAVE_LOCALTIME_R=1 \
        -DHAVE_GMTIME_R=1 \
        -DHAVE_STRCHRNUL=1 \
        -DHAVE_MALLOC_USABLE_SIZE=1 \
        shell.c sqlite3.c -lm -o sqlite3 \
    && strip --strip-all sqlite3

# Assemble the root filesystem of the final image in /rootfs
COPY rootfs/ /rootfs/
COPY rootfs.sh /src/
RUN sh /src/rootfs.sh


FROM scratch

ARG SQLITE_VERSION
ARG IMAGE_VERSION
ARG TINI_VERSION
ARG BUSYBOX_VERSION
ARG SQLITE_UID
ARG SQLITE_GID
ARG BUILD_DATE
ARG GIT_SHA

COPY --from=build /rootfs/ /

LABEL org.opencontainers.image.title="SQLite" \
    org.opencontainers.image.description="Minimal, production-ready, hardened and secure SQLite Docker image." \
    org.opencontainers.image.version="${SQLITE_VERSION}-v${IMAGE_VERSION}" \
    org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.revision="${GIT_SHA}" \
    org.opencontainers.image.licenses="blessing AND MIT AND GPL-2.0-only AND AGPL-3.0-or-later" \
    org.opencontainers.image.authors="peakimages" \
    org.opencontainers.image.vendor="peakimages" \
    org.opencontainers.image.url="https://hub.docker.com/r/peakimages/sqlite" \
    org.opencontainers.image.source="https://github.com/peakimages/sqlite" \
    org.opencontainers.image.documentation="https://github.com/peakimages/sqlite#readme" \
    org.opencontainers.image.base.name="scratch" \
    dev.peakimages.sqlite.version="${SQLITE_VERSION}" \
    dev.peakimages.sqlite.extensions="fts3,fts4,fts5,rtree,geopoly,math,dbstat,soundex" \
    dev.peakimages.tini.version="${TINI_VERSION}" \
    dev.peakimages.busybox.version="${BUSYBOX_VERSION}" \
    dev.peakimages.image.version="${IMAGE_VERSION}"

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    SQLITE_DATABASES=database.sqlite \
    SQLITE_JOURNAL_MODE=WAL \
    SQLITE_AUTO_VACUUM=NONE \
    SQLITE_PAGE_SIZE=4096

WORKDIR /var/lib/sqlite
USER ${SQLITE_UID}:${SQLITE_GID}

STOPSIGNAL SIGTERM
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]

HEALTHCHECK --interval=20s --timeout=5s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]

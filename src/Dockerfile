# syntax=docker/dockerfile:1

# Set by scripts/check-upstream.sh
ARG SQLITE_VERSION=3.54.1

# Dependencies
# https://hub.docker.com/_/alpine/tags?name=3.24.4
ARG BASE_IMAGE=alpine:3.24.4@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf
ARG DISTRO=alpine-3.24
# https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/tini-static
ARG TINI_VERSION=0.19.0-r3
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/busybox-static
ARG BUSYBOX_VERSION=1.37.0-r31

# Set by the build workflow
ARG IMAGE_VERSION
ARG SOURCE_DATE_EPOCH
ARG CREATED
ARG GIT_SHA

FROM ${BASE_IMAGE} AS build

ARG SQLITE_VERSION
ARG TINI_VERSION
ARG BUSYBOX_VERSION

# curl, jq and openssl are only used during the build stage, so they are not pinned to a specific version
# hadolint ignore=DL3018
RUN apk add --no-cache build-base curl jq openssl tini-static=${TINI_VERSION} busybox-static=${BUSYBOX_VERSION}

WORKDIR /src
COPY --chmod=0644 upstream.json verify.sh ./
RUN jq --arg version "$SQLITE_VERSION" '.sqlite[] | select(.version == $version)' upstream.json > sqlite.json \
    && curl --proto '=https' --tlsv1.2 -sSf --retry 3 -o sqlite.zip "$(jq -r .url sqlite.json)" \
    && sh verify.sh

# Compile SQLite and the sqlite3 shell into one static binary using recommended compile time options:
# https://sqlite.org/compile.html#recommended_compile_time_options and https://sqlite.org/cli.html#compiling_the_command_line_interface
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
        -DSQLITE_ENABLE_DBPAGE_VTAB \
        -DSQLITE_ENABLE_STMTVTAB \
        -DSQLITE_ENABLE_EXPLAIN_COMMENTS \
        -DSQLITE_ENABLE_UNKNOWN_SQL_FUNCTION \
        -DSQLITE_ENABLE_OFFSET_SQL_FUNC \
        -DSQLITE_SOUNDEX \
        -DHAVE_USLEEP=1 \
        -DHAVE_FDATASYNC=1 \
        -DHAVE_LOCALTIME_R=1 \
        -DHAVE_GMTIME_R=1 \
        -DHAVE_STRCHRNUL=1 \
        -DHAVE_MALLOC_USABLE_SIZE=1 \
        shell.c sqlite3.c -lm -o sqlite3 \
    && strip --strip-all sqlite3

COPY --chmod=0755 rootfs/ /rootfs/
COPY --chmod=0644 rootfs.sh /src/
RUN sh /src/rootfs.sh

COPY --chmod=0644 sbom.sh /src/
RUN sh /src/sbom.sh peakimages/sqlite "PeakImages SQLite" \
        "generic|sqlite|${SQLITE_VERSION}|blessing|sqlite:sqlite|/usr/local/bin/sqlite3" \
        "apk|tini-static|/sbin/tini" \
        "apk|busybox-static|/bin/busybox"

FROM scratch AS final

ARG DISTRO
ARG SQLITE_VERSION
ARG IMAGE_VERSION
ARG CREATED
ARG GIT_SHA

COPY --from=build /rootfs/ /

LABEL org.opencontainers.image.title="SQLite" \
    org.opencontainers.image.description="Minimal, production-ready, hardened and secure SQLite Docker image." \
    org.opencontainers.image.version="${SQLITE_VERSION}-v${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${GIT_SHA}" \
    org.opencontainers.image.created="${CREATED}" \
    org.opencontainers.image.licenses="AGPL-3.0-or-later AND blessing" \
    org.opencontainers.image.authors="PeakImages" \
    org.opencontainers.image.vendor="PeakImages" \
    org.opencontainers.image.url="https://hub.docker.com/r/peakimages/sqlite" \
    org.opencontainers.image.documentation="https://github.com/peakimages/sqlite#readme" \
    org.opencontainers.image.source="https://github.com/peakimages/sqlite" \
    org.opencontainers.image.base.name="" \
    org.opencontainers.image.base.digest="" \
    dev.peakimages.image.version="${IMAGE_VERSION}" \
    dev.peakimages.image.upstream.version="${SQLITE_VERSION}" \
    dev.peakimages.image.distro="${DISTRO}" \
    dev.peakimages.image.variant="runtime" \
    dev.peakimages.image.flavor="" \
    dev.peakimages.image.shell="busybox" \
    dev.peakimages.image.package-manager=""

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    SQLITE_DATABASES=database.sqlite \
    SQLITE_JOURNAL_MODE=WAL \
    SQLITE_AUTO_VACUUM=NONE \
    SQLITE_PAGE_SIZE=4096

WORKDIR /var/lib/sqlite
USER 65532:65532

STOPSIGNAL SIGTERM
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]

HEALTHCHECK --interval=20s --timeout=5s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]

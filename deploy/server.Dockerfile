# Kaname server image (design D5). Build from the repository root:
#
#   docker build --platform linux/amd64 -f deploy/server.Dockerfile .
#
# The Flutter and Dart toolchain comes only from mise.toml and mise.lock, in
# locked mode, so this file states no Flutter or Dart version. Flutter's Linux
# archive is x64 only: build and run the image as linux/amd64.
#
# deploy/server.Dockerfile.dockerignore is the build context's deny-by-default
# allow-list; it never admits passwords or .env files.

# Digests are the multi-arch index digests of debian:trixie and
# debian:trixie-slim (docker buildx imagetools inspect <image:tag>).
FROM debian:trixie@sha256:9c6e381421d0f48d1b8133e573f33c185ee16cbf505eda9c4a8a4791b25ea8a6 AS build

# Same mise version as CI (.github/workflows/ci.yml), installed from its
# GitHub release asset with the SHA-256 published in the release's
# SHASUMS256.txt. MISE_LOCKED makes `mise install` use only mise.lock.
ENV MISE_VERSION=2026.11.8 \
    MISE_SHA256=32b6abe844efa43d37d7ac4ed21d2ec41e9479d66feb19b0db8d2c548cd6e36d \
    MISE_DATA_DIR=/opt/mise \
    MISE_LOCKED=1 \
    MISE_YES=1 \
    MISE_EXEC_AUTO_INSTALL=0 \
    MISE_AUTO_INSTALL=0

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL -o /usr/local/bin/mise \
        "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64" \
    && echo "${MISE_SHA256}  /usr/local/bin/mise" | sha256sum --check --strict - \
    && chmod 0755 /usr/local/bin/mise

WORKDIR /src

# Toolchain first: this layer changes only with mise.toml or mise.lock. Only
# flutter is installed; java, node and openspec are not needed to compile.
COPY mise.toml mise.lock ./
RUN mise trust /src/mise.toml && mise install --locked flutter

# Every workspace member's pubspec and the lockfile, then resolve exactly what
# pubspec.lock holds; a stale lockfile fails here instead of re-resolving.
COPY pubspec.yaml pubspec.lock ./
COPY app/pubspec.yaml app/
COPY app_packages/kaname_ember_ui/pubspec.yaml app_packages/kaname_ember_ui/
COPY packages/kaname_core/pubspec.yaml packages/kaname_core/
COPY packages/kaname_static_data/pubspec.yaml packages/kaname_static_data/
COPY spikes/kaname_grid_spike/pubspec.yaml spikes/kaname_grid_spike/
COPY tools/kaname_tools/pubspec.yaml tools/kaname_tools/
COPY server/kaname_client/pubspec.yaml server/kaname_client/
COPY server/kaname_server/pubspec.yaml server/kaname_server/
RUN mise exec -- flutter pub get --enforce-lockfile

COPY packages/kaname_core/lib packages/kaname_core/lib
COPY packages/kaname_static_data/lib packages/kaname_static_data/lib
COPY server/kaname_client/lib server/kaname_client/lib
COPY server/kaname_server/bin server/kaname_server/bin
COPY server/kaname_server/lib server/kaname_server/lib
# `dart build cli`, not `dart compile exe`: the server's dependencies (sqlite3)
# have build hooks, which `dart compile` refuses. It AOT-compiles the
# entrypoint and bundles its native libraries: bundle/bin and bundle/lib.
RUN mise exec -- dart --version \
    && mise exec -- dart build cli \
        --target server/kaname_server/bin/main.dart --output /out

FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2 AS runtime

# curl serves the Compose healthcheck against /readyz.
RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --home-dir /app --shell /usr/sbin/nologin kaname

WORKDIR /app
COPY --from=build /out/bundle/ ./
COPY server/kaname_server/config ./config
COPY server/kaname_server/migrations ./migrations

USER kaname
EXPOSE 8080

# Serverpod reads config/ and migrations/ relative to the working directory.
# Compose overrides the command, for example for the one-shot migration step:
# --mode production --role maintenance --apply-migrations
ENTRYPOINT ["./bin/main"]
CMD ["--mode", "production"]

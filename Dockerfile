# One image definition for every NZBGet toolchain tag.
# Images use the host platform. Only linux/amd64 hosts are supported.
#
# Layout (TARGET selects which of these are installed):
#   linux-<arch>     /opt/nzbget/linux/<arch>
#   freebsd-<arch>   /opt/nzbget/freebsd/sysroot-<arch>
#   android          /opt/nzbget/android/{llvm,sysroot,libcxx,api-level}
#   all              every tree above
#
# A tarball in dist/ is unpacked. A missing tarball is compiled.
#   dist/linux-<arch>.tar.gz
#   dist/freebsd-<arch>.tar.gz
#   dist/android.tar.gz
#
# Build-args:
#   PLATFORM        linux | freebsd | android | all (default all)
#                   Which toolchains/<PLATFORM>/ scripts are copied.
#                   all copies the whole toolchains/ tree.
#   TARGET          linux-<arch> | freebsd-<arch> | android | all (default all)
#                   What assemble.sh installs. Arch lists: toolchains/assemble.sh.
#   IMAGE_VERSION   LABEL only, after filesystem layers. Repo VERSION file.
#
# Stages:
#   artifact            tarball(s) in /out (compile or unpack dist/)
#   image               unpack dist/ into a runtime image; no compile stages
#   image-from-source   default; compile (or unpack dist/ in compile) then pack

# linux | freebsd | android | all
ARG PLATFORM=all
# linux-<arch> | freebsd-<arch> | android | all
ARG TARGET=all

FROM debian:trixie-slim AS build-base
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        bison \
        ca-certificates \
        cmake \
        curl \
        file \
        flex \
        gawk \
        git \
        libarchive-tools \
        ncurses-bin \
        ninja-build \
        patch \
        python3 \
        texinfo \
        unzip \
        wget \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

FROM build-base AS compile
ARG PLATFORM
ARG TARGET
ENV NZBGET_LINUX_TOOLCHAIN_DIR=/opt/nzbget/linux \
    NZBGET_ANDROID_TOOLCHAIN_DIR=/opt/nzbget/android \
    FREEBSD_PREFIX=/opt/nzbget/freebsd
COPY toolchains/assemble.sh /usr/src/nzbget-musl-builder/toolchains/assemble.sh
COPY toolchains/${PLATFORM} /usr/src/nzbget-musl-builder/toolchains/${PLATFORM}
COPY dist /tmp/dist
RUN --mount=type=cache,id=nzbget-build-${TARGET},target=/usr/src/nzbget-musl-builder/build \
    TARGET="$TARGET" \
    bash /usr/src/nzbget-musl-builder/toolchains/assemble.sh

FROM compile AS linux
FROM compile AS freebsd
FROM compile AS android

FROM build-base AS all
ARG TARGET
ENV NZBGET_LINUX_TOOLCHAIN_DIR=/opt/nzbget/linux \
    NZBGET_ANDROID_TOOLCHAIN_DIR=/opt/nzbget/android \
    FREEBSD_PREFIX=/opt/nzbget/freebsd
COPY toolchains /usr/src/nzbget-musl-builder/toolchains
COPY dist /tmp/dist
RUN --mount=type=cache,id=nzbget-build-${TARGET},target=/usr/src/nzbget-musl-builder/build \
    TARGET="$TARGET" \
    bash /usr/src/nzbget-musl-builder/toolchains/assemble.sh

ARG PLATFORM=all
FROM ${PLATFORM} AS toolchain

FROM scratch AS artifact
COPY --from=toolchain /out/ /

FROM debian:trixie-slim AS image-runtime
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    NZBGET_LINUX_TOOLCHAIN_DIR=/opt/nzbget/linux \
    NZBGET_ANDROID_TOOLCHAIN_DIR=/opt/nzbget/android \
    FREEBSD_PREFIX=/opt/nzbget/freebsd \
    PATH=/usr/lib/llvm-19/bin:${PATH}
RUN apt-get update && apt-get install -y --no-install-recommends \
        binutils \
        ca-certificates \
        clang-19 \
        cmake \
        curl \
        g++ \
        git \
        lld-19 \
        llvm-19 \
        make \
        nasm \
        ncurses-bin \
        ninja-build \
        perl \
        python3 \
        unzip \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
CMD ["bash"]

# CI target: unpack dist/ tarballs. Does not depend on compile stages.
FROM image-runtime AS image
COPY dist /tmp/dist
COPY toolchains/assemble.sh /usr/src/nzbget-musl-builder/toolchains/assemble.sh
ARG TARGET
RUN TARGET="$TARGET" \
    DIST=/tmp/dist \
    bash /usr/src/nzbget-musl-builder/toolchains/assemble.sh
ARG IMAGE_VERSION
LABEL org.opencontainers.image.title="nzbget-musl-builder" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.description="NZBGet cross toolchains (${TARGET})"

# Local one-shot: compile (or unpack dist in the toolchain stage) then pack.
FROM image-runtime AS image-from-source
COPY --from=toolchain /opt/nzbget /opt/nzbget
ARG TARGET
ARG IMAGE_VERSION
LABEL org.opencontainers.image.title="nzbget-musl-builder" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.description="NZBGet cross toolchains (${TARGET})"

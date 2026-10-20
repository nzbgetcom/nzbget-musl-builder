# One image definition for every NZBGet toolchain tag.
# The image platform is linux/amd64. TARGET is the cross target, not the host.
#
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
# Image version is the VERSION file in the repo root. Pass it as IMAGE_VERSION.
#   version=$(tr -d '[:space:]' < VERSION)
#   docker build --platform linux/amd64 \
#     --build-arg TARGET=linux-aarch64 --build-arg IMAGE_VERSION="$version" \
#     -t "nzbget-musl-builder:linux-aarch64-${version}" .
#
# CI matrix, export one tarball:
#   docker build --platform linux/amd64 --target artifact \
#     --build-arg TARGET=linux-aarch64 --output type=local,dest=out .
#
# Pack an image from that tarball (place it at dist/linux-aarch64.tar.gz first):
#   docker build --platform linux/amd64 \
#     --build-arg TARGET=linux-aarch64 --build-arg IMAGE_VERSION="$version" \
#     -t "nzbget-musl-builder:linux-aarch64-${version}" .

ARG TARGET=all
ARG LINUX_ARCHS="x86_64 aarch64 armhf armel i686 ppc6xx riscv64"
ARG FREEBSD_ARCHS="x86_64 aarch64"

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

FROM build-base AS toolchain
ARG TARGET
ARG LINUX_ARCHS
ARG FREEBSD_ARCHS
ENV NZBGET_LINUX_TOOLCHAIN_DIR=/opt/nzbget/linux \
    NZBGET_ANDROID_TOOLCHAIN_DIR=/opt/nzbget/android \
    FREEBSD_PREFIX=/opt/nzbget/freebsd
COPY toolchains /usr/src/nzbget-musl-builder/toolchains
COPY dist /tmp/dist
RUN --mount=type=cache,target=/usr/src/nzbget-musl-builder/build \
    TARGET="$TARGET" LINUX_ARCHS="$LINUX_ARCHS" FREEBSD_ARCHS="$FREEBSD_ARCHS" \
    bash /usr/src/nzbget-musl-builder/toolchains/assemble.sh

FROM scratch AS artifact
COPY --from=toolchain /out/ /

FROM debian:trixie-slim AS image
ARG TARGET
ARG IMAGE_VERSION
LABEL org.opencontainers.image.title="nzbget-musl-builder" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.description="NZBGet cross toolchains (${TARGET})"
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
        unzip \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*
COPY --from=toolchain /opt/nzbget /opt/nzbget
WORKDIR /src
CMD ["bash"]

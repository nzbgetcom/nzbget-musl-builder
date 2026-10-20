#!/bin/bash
#
# Install the toolchains selected by TARGET into /opt/nzbget.
# A tarball already in $DIST is unpacked. A missing tarball is built.
#
#   dist/linux-<arch>.tar.gz    arch directory (x86_64/, aarch64/, ...)
#   dist/freebsd-<arch>.tar.gz  sysroot-<arch>/
#   dist/android.tar.gz         llvm/, sysroot/, libcxx/, api-level
#
# Copies of the tarballs are written to $OUT for the artifact stage.

set -euo pipefail

TARGET="${TARGET:-all}"
# linux-<arch> and freebsd-<arch> TARGET values must be in these lists.
LINUX_ARCHS="x86_64 aarch64 armhf armel i686 ppc6xx riscv64"
FREEBSD_ARCHS="x86_64 aarch64"
DIST="${DIST:-/tmp/dist}"
OUT="${OUT:-/out}"
ROOT=$(cd "$(dirname "$0")" && pwd)

known_arch() {
	local arch=$1
	local list=$2
	case " $list " in
		*" $arch "*) return 0 ;;
		*) return 1 ;;
	esac
}

linux_triple() {
	case "$1" in
		x86_64) echo x86_64-linux-musl ;;
		aarch64) echo aarch64-linux-musl ;;
		armhf) echo arm-linux-musleabihf ;;
		armel) echo arm-linux-musleabi ;;
		i686) echo i686-linux-musl ;;
		ppc6xx) echo powerpc-linux-musl ;;
		riscv64) echo riscv64-linux-musl ;;
		*)
			echo "Unknown linux arch: $1" >&2
			exit 1
			;;
	esac
}

install_linux() {
	local arch=$1
	local tarball="$DIST/linux-${arch}.tar.gz"
	local triple
	triple=$(linux_triple "$arch")
	mkdir -p /opt/nzbget/linux "$OUT"
	if [ -f "$tarball" ]; then
		echo "Using $tarball"
		tar -xzf "$tarball" -C /opt/nzbget/linux
		cp -a "$tarball" "$OUT/linux-${arch}.tar.gz"
	else
		echo "Building linux toolchain $arch"
		NZBGET_LINUX_TOOLCHAIN_DIR=/opt/nzbget/linux \
			bash "$ROOT/linux/build-toolchain.sh" "$arch"
		tar -C /opt/nzbget/linux -czf "$OUT/linux-${arch}.tar.gz" "$arch"
	fi
	if [ ! -x "/opt/nzbget/linux/${arch}/bin/${triple}-gcc" ]; then
		echo "Linux toolchain $arch is missing ${triple}-gcc" >&2
		exit 1
	fi
}

install_freebsd() {
	local arch=$1
	local tarball="$DIST/freebsd-${arch}.tar.gz"
	local name="sysroot-${arch}"
	mkdir -p /opt/nzbget/freebsd "$OUT"
	if [ -f "$tarball" ]; then
		echo "Using $tarball"
		tar -xzf "$tarball" -C /opt/nzbget/freebsd
		cp -a "$tarball" "$OUT/freebsd-${arch}.tar.gz"
	else
		echo "Building FreeBSD sysroot $arch"
		FREEBSD_PREFIX=/opt/nzbget/freebsd \
			bash "$ROOT/freebsd/build-toolchain.sh" "$arch" 13.0
		tar -C /opt/nzbget/freebsd -czf "$OUT/freebsd-${arch}.tar.gz" "$name"
	fi
	if [ ! -f "/opt/nzbget/freebsd/${name}/usr/include/stdio.h" ]; then
		echo "FreeBSD sysroot $arch is missing usr/include/stdio.h" >&2
		exit 1
	fi
}

install_android() {
	local tarball="$DIST/android.tar.gz"
	mkdir -p /opt/nzbget/android "$OUT"
	if [ -f "$tarball" ]; then
		echo "Using $tarball"
		tar -xzf "$tarball" -C /opt/nzbget/android
		cp -a "$tarball" "$OUT/android.tar.gz"
	else
		echo "Building Android toolchain"
		NZBGET_ANDROID_TOOLCHAIN_DIR=/opt/nzbget/android \
			bash "$ROOT/android/build-toolchain.sh" all
		tar -C /opt/nzbget/android -czf "$OUT/android.tar.gz" llvm sysroot libcxx api-level
	fi
	if [ ! -x /opt/nzbget/android/llvm/bin/clang ]; then
		echo "Android LLVM clang is missing" >&2
		exit 1
	fi
}

case "$TARGET" in
	all)
		for arch in $LINUX_ARCHS; do
			install_linux "$arch"
		done
		for arch in $FREEBSD_ARCHS; do
			install_freebsd "$arch"
		done
		install_android
		;;
	linux-*)
		arch=${TARGET#linux-}
		known_arch "$arch" "$LINUX_ARCHS" || {
			echo "Unknown TARGET: $TARGET" >&2
			exit 1
		}
		install_linux "$arch"
		;;
	freebsd-*)
		arch=${TARGET#freebsd-}
		known_arch "$arch" "$FREEBSD_ARCHS" || {
			echo "Unknown TARGET: $TARGET" >&2
			exit 1
		}
		install_freebsd "$arch"
		;;
	android)
		install_android
		;;
	*)
		echo "Unknown TARGET: $TARGET" >&2
		echo "Expected linux-<arch>, freebsd-<arch>, android, or all" >&2
		exit 1
		;;
esac

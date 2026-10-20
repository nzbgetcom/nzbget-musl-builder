# nzbget-musl-builder

Images that hold the cross toolchains used to build [NZBGet](https://github.com/nzbgetcom/nzbget). Images use the host platform. Only linux/amd64 hosts are supported. The tag names the cross target.

Images are published at `ghcr.io/nzbgetcom/nzbget-musl-builder`. The tag suffix is the contents of [`VERSION`](VERSION). NZBGet CI pins the same value as `MUSL_BUILDER_VERSION`.

| Tag | What is installed |
| --- | --- |
| `linux-x86_64-1.0` | `/opt/nzbget/linux/x86_64` (`x86_64-linux-musl`) |
| `linux-aarch64-1.0` | `/opt/nzbget/linux/aarch64` (`aarch64-linux-musl`) |
| `linux-armhf-1.0` | `/opt/nzbget/linux/armhf` (`arm-linux-musleabihf`) |
| `linux-armel-1.0` | `/opt/nzbget/linux/armel` (`arm-linux-musleabi`) |
| `linux-i686-1.0` | `/opt/nzbget/linux/i686` (`i686-linux-musl`) |
| `linux-ppc6xx-1.0` | `/opt/nzbget/linux/ppc6xx` (`powerpc-linux-musl`) |
| `linux-riscv64-1.0` | `/opt/nzbget/linux/riscv64` (`riscv64-linux-musl`) |
| `freebsd-x86_64-1.0` | `/opt/nzbget/freebsd/sysroot-x86_64` |
| `freebsd-aarch64-1.0` | `/opt/nzbget/freebsd/sysroot-aarch64` |
| `android-1.0` | `/opt/nzbget/android` (`llvm`, `sysroot`, `libcxx`, `api-level`) |
| `all-1.0` | every tree above |

Linux toolchains are GCC 14.3.0, Binutils 2.44, and musl 1.2.6, built with [musl-cross-make](https://github.com/richfelker/musl-cross-make). FreeBSD images carry a 13.0 sysroot; the compiler is the image's Clang 19. Android images carry LLVM 19.1.7, the Android NDK r26b sysroot, and a static libc++ built for API 21.

Every image is Debian trixie and also has the host tools NZBGet's builds expect: Clang 19, LLD, CMake, Ninja, NASM, g++, make, git, and Python 3. The working directory is `/src`.

## Build

A tarball already in `dist/` is unpacked. A missing tarball is compiled.

`TARGET` is `linux-<arch>`, `freebsd-<arch>`, `android`, or `all` (default `all`). Arch lists are in [`toolchains/assemble.sh`](toolchains/assemble.sh). `PLATFORM` is `linux`, `freebsd`, `android`, or `all` (default `all`) and selects which `toolchains/<PLATFORM>/` scripts are copied. Pass the matching `PLATFORM` so a linux script change does not invalidate freebsd/android layers. `IMAGE_VERSION` is a label only.

One-shot one-platform build with a tag from [`VERSION`](VERSION) (default target `image-from-source` compiles, then packs):

```bash
version=$(tr -d '[:space:]' < VERSION)
docker build \
  --build-arg TARGET=linux-aarch64 \
  --build-arg PLATFORM=linux \
  --build-arg IMAGE_VERSION="$version" \
  -t "nzbget-musl-builder:linux-aarch64-${version}" .
```

All defaults (`PLATFORM=all`, `TARGET=all`): every toolchain, local use, no version:

```bash
docker build -t nzbget-musl-builder .
```

Export one tarball without packing an image:

```bash
docker build --target artifact \
  --build-arg TARGET=linux-aarch64 \
  --build-arg PLATFORM=linux \
  --output type=local,dest=out .
```

Place that file at `dist/linux-aarch64.tar.gz` and pack with `--target image` (unpack only; compile stages are not run):

```bash
docker build --target image \
  --build-arg TARGET=linux-aarch64 \
  --build-arg IMAGE_VERSION="$version" \
  -t "nzbget-musl-builder:linux-aarch64-${version}" .
```

## Publish

[`.github/workflows/build.yml`](.github/workflows/build.yml) runs on `workflow_dispatch` or `workflow_call`. Each architecture is compiled, uploaded as an artifact, then packed into the matching tag and pushed to `ghcr.io/nzbgetcom/nzbget-musl-builder`.

BuildKit cache is stored on GHCR as unversioned tags (`cache-linux-aarch64`, `cache-freebsd-x86_64`, `cache-android`, `cache-image`, …). Those tags are not tied to `VERSION`, so a tag bump months later still hits. Each cache push moves the same tag; the previous digest becomes untagged and is deleted after the run. Tagged images and the live `cache-*` tags are kept.

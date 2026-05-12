#!/bin/sh -e
# This scrip is for cross compilations
# Please run this scrip in docker image: abcfy2/muslcc-toolchain-ubuntu:${CROSS_HOST}
# E.g: docker run -e CROSS_HOST=arm-linux-musleabi -e OPENSSL_COMPILER=linux-armv4 -e QT_DEVICE=linux-arm-generic-g++ --rm -v `git rev-parse --show-toplevel`:/build abcfy2/muslcc-toolchain-ubuntu:arm-linux-musleabi /build/.github/workflows/cross_build.sh
# Artifacts will copy to the same directory.

# value from: https://musl.cc/ (without -cross or -native)
export CROSS_HOST="${CROSS_HOST:-arm-linux-musleabi}"
export TOOLCHAIN_TARGET="${TOOLCHAIN_TARGET:-${CROSS_HOST}}"
export TOOLCHAIN_PREFIX="${TOOLCHAIN_PREFIX:-/cross_root/${TOOLCHAIN_TARGET}}"
# value from openssl source: ./Configure LIST
export OPENSSL_COMPILER="${OPENSSL_COMPILER:-linux-armv4}"
# value from https://github.com/qt/qtbase/tree/dev/mkspecs/
export QT_XPLATFORM="${QT_XPLATFORM}"
# value from https://github.com/qt/qtbase/tree/dev/mkspecs/devices/
export QT_DEVICE="${QT_DEVICE}"
export ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}"
export OPENSSL_VERSION="${OPENSSL_VERSION:-1.1.1w}"
export BOOST_VERSION="${BOOST_VERSION:-1.86.0}"
export QT_MAJOR_VER="${QT_MAJOR_VER:-5.15}"
export QT_VER="${QT_VER:-5.15.18}"
export LIBICONV_VERSION="${LIBICONV_VERSION:-1.17}"
export LIBTORRENT_BRANCH="v1.2.20"
export CROSS_ROOT="${CROSS_ROOT:-$(dirname "${TOOLCHAIN_PREFIX}")}"
export MUSL_TOOLCHAIN_BASE_URLS="${MUSL_TOOLCHAIN_BASE_URLS:-https://more.musl.cc/x86_64-linux-musl https://musl.cc}"

download_file() {
  output_path="${1}"
  shift

  tmp_path="${output_path}.tmp"
  rm -f "${tmp_path}"

  for url in "$@"; do
    echo "Downloading ${url}"
    if wget -T 60 -t 3 -O "${tmp_path}" "${url}"; then
      mv -f "${tmp_path}" "${output_path}"
      return 0
    fi
    rm -f "${tmp_path}"
  done

  echo "Failed to download ${output_path}" >&2
  return 1
}

install_packages() {
  if command -v apk >/dev/null 2>&1; then
    apk add "$@"
  elif command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-suggests --no-install-recommends "$@"
  else
    echo "No supported package manager found" >&2
    return 1
  fi
}

if command -v apk >/dev/null 2>&1; then
  install_packages gcc g++ make file perl autoconf automake libtool tar jq pkgconfig wget linux-headers zip xz bzip2
else
  install_packages gcc g++ make file perl autoconf automake libtool tar jq pkg-config wget linux-libc-dev zip xz-utils bzip2 ca-certificates
fi

TARGET_ARCH="${CROSS_HOST%%-*}"
TARGET_HOST="${CROSS_HOST#*-}"
case "${TARGET_HOST}" in
*"mingw"*)
  TARGET_HOST=win
  if command -v apk >/dev/null 2>&1; then
    install_packages wine
  else
    install_packages wine64
  fi
  export WINEPREFIX=/tmp/
  RUNNER_CHECKER="wine64"
  ;;
*)
  TARGET_HOST=linux
  if command -v apk >/dev/null 2>&1; then
    install_packages "qemu-${TARGET_ARCH}"
  else
    install_packages qemu-user
  fi
  RUNNER_CHECKER="qemu-${TARGET_ARCH}"
  ;;
esac

export PATH="${CROSS_ROOT}/bin:${PATH}"
export CROSS_PREFIX="${TOOLCHAIN_PREFIX}"
export PKG_CONFIG_PATH="${CROSS_PREFIX}/opt/qt/lib/pkgconfig:${CROSS_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
SELF_DIR="$(dirname "$(readlink -f "${0}")")"

mkdir -p "${CROSS_ROOT}" \
  /usr/src/zlib \
  /usr/src/openssl \
  /usr/src/boost \
  /usr/src/libiconv \
  /usr/src/libtorrent \
  /usr/src/qtbase \
  /usr/src/qttools

# toolchain
if command -v "${TOOLCHAIN_TARGET}-gcc" >/dev/null 2>&1; then
  echo "Using preinstalled ${TOOLCHAIN_TARGET} toolchain"
else
  if [ ! -f "${SELF_DIR}/${CROSS_HOST}-cross.tgz" ]; then
    toolchain_urls=""
    for base_url in ${MUSL_TOOLCHAIN_BASE_URLS}; do
      toolchain_urls="${toolchain_urls} ${base_url}/${CROSS_HOST}-cross.tgz"
    done
    # shellcheck disable=SC2086
    download_file "${SELF_DIR}/${CROSS_HOST}-cross.tgz" ${toolchain_urls}
  fi
  tar -zxf "${SELF_DIR}/${CROSS_HOST}-cross.tgz" --transform='s|^\./||S' --strip-components=1 -C "${CROSS_ROOT}"
  export TOOLCHAIN_TARGET="${CROSS_HOST}"
  export TOOLCHAIN_PREFIX="${CROSS_ROOT}/${CROSS_HOST}"
  export CROSS_PREFIX="${TOOLCHAIN_PREFIX}"
  export PATH="${CROSS_ROOT}/bin:${PATH}"
fi
# mingw does not contains posix thread support: https://github.com/meganz/mingw-std-threads
if [ "${TARGET_HOST}" = 'win' ]; then
  if [ ! -f "${SELF_DIR}/mingw-std-threads.tar.gz" ]; then
    wget -c -O "${SELF_DIR}/mingw-std-threads.tar.gz" "https://github.com/meganz/mingw-std-threads/archive/master.tar.gz"
  fi
  mkdir -p /usr/src/mingw-std-threads/
  tar -zxf "${SELF_DIR}/mingw-std-threads.tar.gz" --strip-components=1 -C "/usr/src/mingw-std-threads/"
  cp -fv /usr/src/mingw-std-threads/*.h "${CROSS_PREFIX}/include"
fi

# zlib
if [ ! -f "${SELF_DIR}/zlib.tar.gz" ]; then
  wget -c -O "${SELF_DIR}/zlib.tar.gz" "https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz"
fi
tar -zxf "${SELF_DIR}/zlib.tar.gz" --strip-components=1 -C /usr/src/zlib
cd /usr/src/zlib
if [ "${TARGET_HOST}" = win ]; then
  make -f win32/Makefile.gcc BINARY_PATH="${CROSS_PREFIX}/bin" INCLUDE_PATH="${CROSS_PREFIX}/include" LIBRARY_PATH="${CROSS_PREFIX}/lib" SHARED_MODE=0 PREFIX="${TOOLCHAIN_TARGET}-" -j$(nproc) install
else
  CHOST="${TOOLCHAIN_TARGET}" ./configure --prefix="${CROSS_PREFIX}" --static
  make -j$(nproc)
  make install
fi

# openssl
if [ ! -f "${SELF_DIR}/openssl.tar.gz" ]; then
  openssl_tag="OpenSSL_$(echo "${OPENSSL_VERSION}" | tr . _)"
  wget -c -O "${SELF_DIR}/openssl.tar.gz" "https://github.com/openssl/openssl/releases/download/${openssl_tag}/openssl-${OPENSSL_VERSION}.tar.gz"
fi
tar -zxf "${SELF_DIR}/openssl.tar.gz" --strip-components=1 -C /usr/src/openssl
cd /usr/src/openssl
./Configure -static --cross-compile-prefix="${TOOLCHAIN_TARGET}-" --prefix="${CROSS_PREFIX}" "${OPENSSL_COMPILER}"
make depend
make -j$(nproc)
make install_sw

# boost
if [ ! -f "${SELF_DIR}/boost.tar.bz2" ]; then
  boost_filename="$(echo "boost_${BOOST_VERSION}" | tr . _)"
  wget -c -O "${SELF_DIR}/boost.tar.bz2" "https://archives.boost.io/release/${BOOST_VERSION}/source/${boost_filename}.tar.bz2"
fi
tar -jxf "${SELF_DIR}/boost.tar.bz2" --strip-components=1 -C /usr/src/boost
cd /usr/src/boost
./bootstrap.sh
printf 'using gcc : cross : %s-g++ ;\n' "${TOOLCHAIN_TARGET}" > user-config.jam
./b2 install --user-config=user-config.jam --prefix="${CROSS_PREFIX}" --with-system toolset=gcc-cross variant=release link=static runtime-link=static

# qt
echo "Using qt version: ${QT_VER}"
qtbase_url="https://download.qt.io/archive/qt/${QT_MAJOR_VER}/${QT_VER}/submodules/qtbase-everywhere-opensource-src-${QT_VER}.tar.xz"
qtbase_filename="qtbase-everywhere-opensource-src-${QT_VER}.tar.xz"
qttools_url="https://download.qt.io/archive/qt/${QT_MAJOR_VER}/${QT_VER}/submodules/qttools-everywhere-opensource-src-${QT_VER}.tar.xz"
qttools_filename="qttools-everywhere-opensource-src-${QT_VER}.tar.xz"
if [ ! -f "${SELF_DIR}/${qtbase_filename}" ]; then
  wget -c -O "${SELF_DIR}/${qtbase_filename}" "${qtbase_url}"
fi
if [ ! -f "${SELF_DIR}/${qttools_filename}" ]; then
  wget -c -O "${SELF_DIR}/${qttools_filename}" "${qttools_url}"
fi
tar -Jxf "${SELF_DIR}/${qtbase_filename}" --strip-components=1 -C /usr/src/qtbase
tar -Jxf "${SELF_DIR}/${qttools_filename}" --strip-components=1 -C /usr/src/qttools
cd /usr/src/qtbase
# Remove some options no support by this toolchain
find -name '*.conf' -print0 | xargs -0 -r sed -i 's/-fno-fat-lto-objects//g'
find -name '*.conf' -print0 | xargs -0 -r sed -i 's/-fuse-linker-plugin//g'
find -name '*.conf' -print0 | xargs -0 -r sed -i 's/-mfloat-abi=softfp//g'

# fix gcc 11+ missing <limits>
sed -i '1i #include <limits>' src/corelib/global/qfloat16.h src/corelib/global/qendian.h src/corelib/text/qbytearraymatcher.h
if [ "${TARGET_HOST}" = 'win' ]; then
  export OPENSSL_LIBS="-lssl -lcrypto -lcrypt32 -lws2_32"
  # musl.cc x86_64-w64-mingw32 toolchain not supports thread local
  sed -i '/define\s*Q_COMPILER_THREAD_LOCAL/d' src/corelib/global/qcompilerdetection.h
fi
./configure --prefix=/opt/qt/ -optimize-size -silent --openssl-linked \
  -static -opensource -confirm-license -release -c++std c++17 -no-opengl \
  -no-dbus -no-widgets -no-gui -no-compile-examples -ltcg -make libs -no-pch \
  -nomake tests -nomake examples -no-xcb -no-feature-testlib \
  -hostprefix "${CROSS_ROOT}" ${QT_XPLATFORM:+-xplatform "${QT_XPLATFORM}"} \
  ${QT_DEVICE:+-device "${QT_DEVICE}"} -device-option CROSS_COMPILE="${TOOLCHAIN_TARGET}-" \
  -sysroot "${CROSS_PREFIX}"
make -j$(nproc)
make install
cd /usr/src/qttools
qmake -set prefix "${CROSS_ROOT}"
qmake
# Remove some options no support by this toolchain
find -name '*.conf' -print0 | xargs -0 -r sed -i 's/-fno-fat-lto-objects//g'
find -name '*.conf' -print0 | xargs -0 -r sed -i 's/-fuse-linker-plugin//g'
find -name '*.conf' -print0 | xargs -0 -r sed -i 's/-mfloat-abi=softfp//g'
make -j$(nproc) install
cd "${CROSS_ROOT}/bin"
ln -sf lrelease "lrelease-qt$(echo "${QT_VER}" | cut -d. -f1)"

# libiconv
if [ ! -f "${SELF_DIR}/libiconv.tar.gz" ]; then
  wget -c -O "${SELF_DIR}/libiconv.tar.gz" "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-${LIBICONV_VERSION}.tar.gz"
fi
tar -zxf "${SELF_DIR}/libiconv.tar.gz" --strip-components=1 -C /usr/src/libiconv/
cd /usr/src/libiconv/
./configure CXXFLAGS="-std=c++17" --host="${TOOLCHAIN_TARGET}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared --enable-silent-rules
make -j$(nproc)
make install

# libtorrent
if [ ! -f "${SELF_DIR}/libtorrent.tar.gz" ]; then
  wget -c -O "${SELF_DIR}/libtorrent.tar.gz" "https://github.com/arvidn/libtorrent/archive/${LIBTORRENT_BRANCH}.tar.gz"
fi
tar -zxf "${SELF_DIR}/libtorrent.tar.gz" --strip-components=1 -C /usr/src/libtorrent
cd /usr/src/libtorrent
if [ "${TARGET_HOST}" = 'win' ]; then
  export LIBS="-lcrypt32 -lws2_32"
  # musl.cc x86_64-w64-mingw32 toolchain not supports thread local
  export CPPFLAGS='-D_WIN32_WINNT=0x0602 -DBOOST_NO_CXX11_THREAD_LOCAL'
fi
./bootstrap.sh CXXFLAGS="-std=c++17" --host="${TOOLCHAIN_TARGET}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared --enable-silent-rules --with-boost="${CROSS_PREFIX}" --with-libiconv
# fix x86_64-w64-mingw32 build
if [ "${TARGET_HOST}" = 'win' ]; then
  find -type f \( -name '*.cpp' -o -name '*.hpp' \) -print0 |
    xargs -0 -r sed -i 's/include\s*<condition_variable>/include "mingw.condition_variable.h"/g;
                        s/include\s*<future>/include "mingw.future.h"/g;
                        s/include\s*<invoke>/include "mingw.invoke.h"/g;
                        s/include\s*<mutex>/include "mingw.mutex.h"/g;
                        s/include\s*<shared_mutex>/include "mingw.shared_mutex.h"/g;
                        s/include\s*<thread>/include "mingw.thread.h"/g'
fi
make -j$(nproc)
make install
unset LIBS CPPFLAGS

# build qbittorrent
cd "${SELF_DIR}/../../"
if [ "${TARGET_HOST}" = 'win' ]; then
  find \( -name '*.cpp' -o -name '*.h' \) -type f -print0 |
    xargs -0 -r sed -i 's/Windows\.h/windows.h/g;
      s/Shellapi\.h/shellapi.h/g;
      s/Shlobj\.h/shlobj.h/g;
      s/Ntsecapi\.h/ntsecapi.h/g'
  export LIBS="-lmswsock"
  export CPPFLAGS='-std=c++17 -D_WIN32_WINNT=0x0602'
fi
LIBS="${LIBS} -liconv" ./configure --host="${TOOLCHAIN_TARGET}" --prefix="${CROSS_PREFIX}" --disable-gui --with-boost="${CROSS_PREFIX}" CXXFLAGS="-std=c++17 ${CPPFLAGS}" LDFLAGS='-s -static --static'
make -j$(nproc)
make install
unset LIBS CPPFLAGS
if [ "${TARGET_HOST}" = 'win' ]; then
  cp -fv "src/release/qbittorrent-nox.exe" /tmp/
else
  cp -fv "${CROSS_PREFIX}/bin/qbittorrent-nox" /tmp/
fi

# check
"${RUNNER_CHECKER}" /tmp/qbittorrent-nox* --version 2>/dev/null

# archive qbittorrent
zip -j9v "${SELF_DIR}/qbittorrent-nox_${CROSS_HOST}_static.zip" /tmp/qbittorrent-nox*

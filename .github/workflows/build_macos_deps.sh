#!/usr/bin/env bash
set -euo pipefail

TARGET_ARCH="${TARGET_ARCH:-arm64}"
LIBTORRENT_VERSION="${LIBTORRENT_VERSION:-v1.2.20}"
QT_VERSION="${QT_VERSION:-5.15.18}"
OPENSSL_VERSION="${OPENSSL_VERSION:-1.1.1w}"
BOOST_VERSION="${BOOST_VERSION:-1.86.0}"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-11.0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-${ROOT_DIR}/../macos-deps-build-${TARGET_ARCH}}"
DEPS_PREFIX="${DEPS_PREFIX:-${ROOT_DIR}/../macos-deps-${TARGET_ARCH}}"

OPENSSL_ROOT_DIR="${OPENSSL_ROOT_DIR:-${DEPS_PREFIX}/openssl-${OPENSSL_VERSION}}"
BOOST_ROOT="${BOOST_ROOT:-${DEPS_PREFIX}/boost_1_81_0}"
QT_ROOT="${QT_ROOT:-${DEPS_PREFIX}/qt-${QT_VERSION}}"
LIBTORRENT_ROOT="${LIBTORRENT_ROOT:-${DEPS_PREFIX}}"
CMAKE_IGNORE_PREFIX_PATH="${CMAKE_IGNORE_PREFIX_PATH:-/opt/homebrew;/usr/local}"

OPENSSL_SHA256="cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8"
BOOST_SHA256="1bed88e40401b2cb7a1f76d4bab499e352fa4d0c5f31c0dbae64e24d34d7513b"
QT_SHA256="cea1fbabf02455f3f0e8eaa839f5d6f45cdb56b62c8a83af5c1d00ac05f912ea"

JOBS="${JOBS:-$(sysctl -n hw.logicalcpu)}"
export MACOSX_DEPLOYMENT_TARGET
export CMAKE_IGNORE_PREFIX_PATH
export PATH="/opt/homebrew/opt/ccache/libexec:/usr/local/opt/ccache/libexec:${PATH}"
export PKG_CONFIG_PATH="${OPENSSL_ROOT_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

download() {
  local url="$1"
  local output="$2"
  local sha256="$3"

  if [[ ! -f "${output}" ]]; then
    curl --fail --show-error --retry 3 --retry-delay 5 -L -o "${output}" "${url}"
  fi

  echo "${sha256}  ${output}" | shasum -a 256 -c -
}

extract_once() {
  local archive="$1"
  local destination="$2"

  if [[ ! -d "${destination}" ]]; then
    mkdir -p "$(dirname "${destination}")"
    tar -xf "${archive}" -C "$(dirname "${destination}")"
  fi
}

mkdir -p "${BUILD_ROOT}" "${DEPS_PREFIX}"

if [[ "${TARGET_ARCH}" == "x86_64" && "$(uname -m)" == "arm64" ]]; then
  softwareupdate --install-rosetta --agree-to-license || true
fi

if [[ ! -f "${OPENSSL_ROOT_DIR}/lib/libssl.dylib" ]]; then
  OPENSSL_TARBALL="${BUILD_ROOT}/openssl-${OPENSSL_VERSION}.tar.gz"
  download \
    "https://github.com/openssl/openssl/releases/download/OpenSSL_1_1_1w/openssl-${OPENSSL_VERSION}.tar.gz" \
    "${OPENSSL_TARBALL}" \
    "${OPENSSL_SHA256}"

  extract_once "${OPENSSL_TARBALL}" "${BUILD_ROOT}/openssl-${OPENSSL_VERSION}"
  pushd "${BUILD_ROOT}/openssl-${OPENSSL_VERSION}"
  ./Configure "darwin64-${TARGET_ARCH}-cc" no-tests --prefix="${OPENSSL_ROOT_DIR}" --openssldir="${OPENSSL_ROOT_DIR}/ssl"
  make -j"${JOBS}"
  make install_sw
  popd
fi

if [[ ! -d "${BOOST_ROOT}" ]]; then
  BOOST_UNDERSCORE_VERSION="${BOOST_VERSION//./_}"
  BOOST_TARBALL="${BUILD_ROOT}/boost_${BOOST_UNDERSCORE_VERSION}.tar.bz2"
  download \
    "https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_UNDERSCORE_VERSION}.tar.bz2" \
    "${BOOST_TARBALL}" \
    "${BOOST_SHA256}"

  tar -xf "${BOOST_TARBALL}" -C "${DEPS_PREFIX}"
fi

if [[ ! -x "${QT_ROOT}/bin/qmake" ]]; then
  QT_TARBALL="${BUILD_ROOT}/qt-everywhere-opensource-src-${QT_VERSION}.tar.xz"
  download \
    "https://download.qt.io/archive/qt/5.15/${QT_VERSION}/single/qt-everywhere-opensource-src-${QT_VERSION}.tar.xz" \
    "${QT_TARBALL}" \
    "${QT_SHA256}"

  extract_once "${QT_TARBALL}" "${BUILD_ROOT}/qt-everywhere-src-${QT_VERSION}"
  pushd "${BUILD_ROOT}/qt-everywhere-src-${QT_VERSION}"
  export OPENSSL_LIBS="-L${OPENSSL_ROOT_DIR}/lib -lssl -lcrypto"
  ./configure \
    -prefix "${QT_ROOT}" \
    -release \
    -opensource \
    -confirm-license \
    -platform macx-clang \
    -nomake examples \
    -nomake tests \
    -no-rpath \
    -no-dbus \
    -no-icu \
    -no-cups \
    -no-opengl \
    -qt-zlib \
    -qt-pcre \
    -qt-libpng \
    -qt-libjpeg \
    -qt-freetype \
    -openssl-linked \
    -skip qt3d \
    -skip qtactiveqt \
    -skip qtandroidextras \
    -skip qtcanvas3d \
    -skip qtcharts \
    -skip qtconnectivity \
    -skip qtdatavis3d \
    -skip qtdeclarative \
    -skip qtdoc \
    -skip qtgamepad \
    -skip qtgraphicaleffects \
    -skip qtimageformats \
    -skip qtlocation \
    -skip qtmultimedia \
    -skip qtnetworkauth \
    -skip qtpurchasing \
    -skip qtquickcontrols \
    -skip qtquickcontrols2 \
    -skip qtremoteobjects \
    -skip qtscript \
    -skip qtscxml \
    -skip qtsensors \
    -skip qtserialbus \
    -skip qtserialport \
    -skip qtspeech \
    -skip qtvirtualkeyboard \
    -skip qtwayland \
    -skip qtwebchannel \
    -skip qtwebengine \
    -skip qtwebglplugin \
    -skip qtwebsockets \
    -skip qtwinextras \
    -skip qtx11extras \
    -skip qtxmlpatterns \
    "OPENSSL_PREFIX=${OPENSSL_ROOT_DIR}" \
    "QMAKE_APPLE_DEVICE_ARCHS=${TARGET_ARCH}" \
    "QMAKE_CFLAGS+=-arch ${TARGET_ARCH}" \
    "QMAKE_CXXFLAGS+=-arch ${TARGET_ARCH}" \
    "QMAKE_LFLAGS+=-arch ${TARGET_ARCH}" \
    "QMAKE_MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET}"
  make -j"${JOBS}"
  make install
  popd
fi

if [[ ! -d "${ROOT_DIR}/libtorrent/.git" ]]; then
  git clone --branch "${LIBTORRENT_VERSION}" --depth 1 https://github.com/arvidn/libtorrent.git "${ROOT_DIR}/libtorrent"
fi

pushd "${ROOT_DIR}/libtorrent"
git fetch --depth 1 origin "${LIBTORRENT_VERSION}"
git checkout FETCH_HEAD
git submodule update --init --recursive
cmake \
  -B build-${TARGET_ARCH} \
  -G "Ninja" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_CXX_STANDARD=17 \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_OSX_ARCHITECTURES="${TARGET_ARCH}" \
  -DCMAKE_IGNORE_PREFIX_PATH="${CMAKE_IGNORE_PREFIX_PATH}" \
  -DCMAKE_INSTALL_PREFIX="${LIBTORRENT_ROOT}" \
  -DBOOST_ROOT="${BOOST_ROOT}" \
  -Ddeprecated-functions=OFF \
  -DOPENSSL_ROOT_DIR="${OPENSSL_ROOT_DIR}" \
  -DOPENSSL_INCLUDE_DIR="${OPENSSL_ROOT_DIR}/include" \
  -DOPENSSL_SSL_LIBRARY="${OPENSSL_ROOT_DIR}/lib/libssl.dylib" \
  -DOPENSSL_CRYPTO_LIBRARY="${OPENSSL_ROOT_DIR}/lib/libcrypto.dylib"
cmake --build build-${TARGET_ARCH}
cmake --install build-${TARGET_ARCH}
popd

ENV_FILE="${DEPS_PREFIX}/qbt-build-env.sh"
{
  printf 'export DEPS_PREFIX=%q\n' "${DEPS_PREFIX}"
  printf 'export OPENSSL_ROOT_DIR=%q\n' "${OPENSSL_ROOT_DIR}"
  printf 'export BOOST_ROOT=%q\n' "${BOOST_ROOT}"
  printf 'export QT_ROOT=%q\n' "${QT_ROOT}"
  printf 'export CMAKE_IGNORE_PREFIX_PATH=%q\n' "${CMAKE_IGNORE_PREFIX_PATH}"
  printf 'export CMAKE_PREFIX_PATH=%q\n' "${LIBTORRENT_ROOT}:${QT_ROOT}"
  printf 'export PKG_CONFIG_PATH=%q\n' "${OPENSSL_ROOT_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  printf 'export PATH=%q:${PATH}\n' "${QT_ROOT}/bin"
} > "${ENV_FILE}"
echo "Wrote ${ENV_FILE}"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "DEPS_PREFIX=${DEPS_PREFIX}"
    echo "OPENSSL_ROOT_DIR=${OPENSSL_ROOT_DIR}"
    echo "BOOST_ROOT=${BOOST_ROOT}"
    echo "QT_ROOT=${QT_ROOT}"
    echo "CMAKE_IGNORE_PREFIX_PATH=${CMAKE_IGNORE_PREFIX_PATH}"
    echo "CMAKE_PREFIX_PATH=${LIBTORRENT_ROOT}:${QT_ROOT}"
    echo "PKG_CONFIG_PATH=${OPENSSL_ROOT_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  } >> "${GITHUB_ENV}"
fi

if [[ -n "${GITHUB_PATH:-}" ]]; then
  {
    echo "${QT_ROOT}/bin"
    echo "/opt/homebrew/opt/ccache/libexec"
    echo "/usr/local/opt/ccache/libexec"
  } >> "${GITHUB_PATH}"
fi

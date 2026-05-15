#!/bin/bash -e
# This scrip is for building AppImage
# Please run this scrip in docker image: ubuntu:16.04
# E.g: docker run --rm -v `git rev-parse --show-toplevel`:/build ubuntu:16.04 /build/.github/workflows/build_appimage.sh
# Artifacts will copy to the same directory.

# Ubuntu mirror for local building
if [ -n "${UBUNTU_MIRROR:-}" ]; then
  source /etc/os-release
  cat >/etc/apt/sources.list <<EOF
deb ${UBUNTU_MIRROR} ${UBUNTU_CODENAME} main restricted universe multiverse
deb ${UBUNTU_MIRROR} ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb ${UBUNTU_MIRROR} ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb ${UBUNTU_MIRROR} ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF
fi
export PIP_INDEX_URL="https://mirrors.aliyun.com/pypi/simple/"

apt update
apt install -y software-properties-common
apt-add-repository -y ppa:savoury1/backports
apt-add-repository -y ppa:savoury1/gcc-defaults-9
apt update
apt install -y --no-install-suggests --no-install-recommends \
  curl \
  gcc \
  g++ \
  make \
  autoconf \
  automake \
  pkg-config \
  file \
  zlib1g-dev \
  libssl-dev \
  libtool \
  p7zip-full \
  python3-semantic-version \
  python3-lxml \
  python3-requests \
  python3-pip \
  python3-stdeb \
  libfontconfig1 \
  libgl1-mesa-dev \
  libxcb-icccm4 \
  libxcb-image0 \
  libxcb-keysyms1 \
  libxcb-render-util0 \
  libxcb-xinerama0 \
  libxcb-xkb1 \
  libxkbcommon-x11-0 \
  libpq5 \
  libxcb-randr0 \
  libxcb-shape0 \
  libodbc1 \
  libxcb-xfixes0 \
  libegl1-mesa

# Force refresh ld.so.cache
ldconfig
SELF_DIR="$(dirname "$(readlink -f "${0}")")"
export PYTHONWARNINGS=ignore:DEPRECATION

# install qt
if [ ! -d "${HOME}/Qt" ]; then
  mkdir -p "${HOME}/Qt"
  qt_repo_url="https://download.qt.io/online/qtsdkrepository/linux_x64/desktop/qt5_5152/qt.qt5.5152.gcc_64"
  qt_packages="
    5.15.2-0-202011130601icu-linux-Rhel7.2-x64.7z
    5.15.2-0-202011130601qtbase-Linux-RHEL_7_6-GCC-Linux-RHEL_7_6-X86_64.7z
    5.15.2-0-202011130601qtsvg-Linux-RHEL_7_6-GCC-Linux-RHEL_7_6-X86_64.7z
    5.15.2-0-202011130601qttools-Linux-RHEL_7_6-GCC-Linux-RHEL_7_6-X86_64.7z
  "
  for qt_package in ${qt_packages}; do
    curl -fL --retry 3 --retry-delay 5 -o "/tmp/${qt_package}" "${qt_repo_url}/${qt_package}"
    7z x -y -o"${HOME}/Qt" "/tmp/${qt_package}"
  done
fi
export QT_BASE_DIR="$(ls -rd "${HOME}/Qt"/*/gcc_64 | head -1)"
export QTDIR=$QT_BASE_DIR
export PATH=$QT_BASE_DIR/bin:$PATH
export LD_LIBRARY_PATH=$QT_BASE_DIR/lib:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=$QT_BASE_DIR/lib/pkgconfig:$PKG_CONFIG_PATH
export QT_QMAKE="${QT_BASE_DIR}/bin"
sed -i.bak 's/Enterprise/OpenSource/g;s/licheck.*//g' "${QT_BASE_DIR}/mkspecs/qconfig.pri"

BOOST_VERSION="${BOOST_VERSION:-1.86.0}"
BOOST_FILENAME="$(echo "boost_${BOOST_VERSION}" | tr . _)"

# build boost
mkdir -p /usr/src/boost
if [ ! -f /usr/src/boost/.unpack_ok ]; then
  curl -fL --retry 3 --retry-delay 5 "https://archives.boost.io/release/${BOOST_VERSION}/source/${BOOST_FILENAME}.tar.bz2" |
    tar -jxf - -C /usr/src/boost --strip-components 1
fi
touch "/usr/src/boost/.unpack_ok"
cd /usr/src/boost
./bootstrap.sh
./b2 install --with-system variant=release
ldconfig

# build libtorrent-rasterbar
mkdir -p /usr/src/libtorrent-rasterbar
[ -f /usr/src/libtorrent-rasterbar/.unpack_ok ] ||
  curl -ksSfL https://github.com/arvidn/libtorrent/archive/v1.2.20.tar.gz |
  tar -zxf - -C /usr/src/libtorrent-rasterbar --strip-components 1
touch "/usr/src/libtorrent-rasterbar/.unpack_ok"
cd "/usr/src/libtorrent-rasterbar/"
CXXFLAGS="-std=c++17" CPPFLAGS="-std=c++17" ./bootstrap.sh --prefix=/usr --with-boost="/usr/local" --with-boost-libdir="/usr/local/lib" --disable-debug --disable-maintainer-mode --with-libiconv
make clean
make -j$(nproc)
make install
ldconfig

# build qbittorrent
cd "${SELF_DIR}/../../"
./configure --prefix=/tmp/qbee/AppDir/usr --with-boost="/usr/local" --with-boost-libdir="/usr/local/lib" CXXFLAGS="-std=c++17" CPPFLAGS="-std=c++17" || (cat config.log && exit 1)
make install -j$(nproc)

# build AppImage
[ -x "/tmp/linuxdeploy-x86_64.AppImage" ] || curl -LC- -o /tmp/linuxdeploy-x86_64.AppImage "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
[ -x "/tmp/linuxdeploy-plugin-qt-x86_64.AppImage" ] || curl -LC- -o /tmp/linuxdeploy-plugin-qt-x86_64.AppImage "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage"
chmod -v +x '/tmp/linuxdeploy-plugin-qt-x86_64.AppImage' '/tmp/linuxdeploy-x86_64.AppImage'
# Fix run in docker, see: https://github.com/linuxdeploy/linuxdeploy/issues/86
# sed -i 's|AI\x02|\x00\x00\x00|' '/tmp/linuxdeploy-plugin-qt-x86_64.AppImage' '/tmp/linuxdeploy-x86_64.AppImage'
cd "/tmp/qbee"
mkdir -p "/tmp/qbee/AppDir/apprun-hooks/"
echo 'export XDG_DATA_DIRS="${APPDIR:-"$(dirname "${BASH_SOURCE[0]}")/.."}/usr/share:${XDG_DATA_DIRS}:/usr/share:/usr/local/share"' >"/tmp/qbee/AppDir/apprun-hooks/xdg_data_dirs.sh"
APPIMAGE_EXTRACT_AND_RUN=1 \
  OUTPUT='qBittorrent-Enhanced-Edition.AppImage' \
  UPDATE_INFORMATION="zsync|https://github.com/${GITHUB_REPOSITORY}/releases/latest/download/qBittorrent-Enhanced-Edition.AppImage.zsync" \
  /tmp/linuxdeploy-x86_64.AppImage --appdir="/tmp/qbee/AppDir" --output=appimage --plugin qt

cp -fv /tmp/qbee/qBittorrent-Enhanced-Edition.AppImage /tmp/qbee/qBittorrent-Enhanced-Edition.AppImage.zsync "${SELF_DIR}"

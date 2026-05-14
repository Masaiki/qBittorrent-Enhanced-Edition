# XrepoDependencies.cmake
#
# Optional dependency provider for CI/local builds. It keeps the qBittorrent
# build on CMake while using xrepo to download, build and install third-party
# dependencies.

set(_qbt_libtorrent_xrepo_package "${CMAKE_CURRENT_LIST_DIR}/xrepo-packages/xmake.lua")

include("${CMAKE_CURRENT_LIST_DIR}/xrepo.cmake")

set(_qbt_xrepo_mode release)
set(_qbt_xrepo_static_runtime_config "")
if(MSVC AND NOT MSVC_RUNTIME_DYNAMIC)
    set(_qbt_xrepo_static_runtime_config ",vs_runtime=MT")
endif()

# Match the old Windows static dependency chain as closely as xrepo packages
# allow. Qt5 in xrepo is currently provided by the qt5base package (5.15.2).
# Win ARM64 coverage and Qt static plugin target coverage are intentionally not
# handled here yet.
xrepo_package("boost 1.86.0"
    CONFIGS "shared=false,cmake=true,asio=true,chrono=true,date_time=true,filesystem=true,random=true,system=true${_qbt_xrepo_static_runtime_config}"
    MODE ${_qbt_xrepo_mode}
)
xrepo_package("openssl 1.1.1-w"
    CONFIGS "shared=false${_qbt_xrepo_static_runtime_config}"
    MODE ${_qbt_xrepo_mode}
)
xrepo_package("zlib 1.3.1"
    CONFIGS "shared=false${_qbt_xrepo_static_runtime_config}"
    MODE ${_qbt_xrepo_mode}
)
xrepo_package("qt5base 5.15.2"
    MODE ${_qbt_xrepo_mode}
)
xrepo_package("${_qbt_libtorrent_xrepo_package}"
    ALIAS libtorrent-rasterbar
    CONFIGS "shared=false,deprecated_functions=true,iconv=false${_qbt_xrepo_static_runtime_config}"
    MODE ${_qbt_xrepo_mode}
)

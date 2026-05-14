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
xrepo_package("qt5core 5.15.2"
    MODE ${_qbt_xrepo_mode}
)
set(_qbt_libtorrent_xrepo_configs "shared=false,deprecated_functions=true,iconv=false${_qbt_xrepo_static_runtime_config}")
if(XREPO_BUILD_PARALLEL_JOBS)
    set(_qbt_xrepo_build_parallel_jobs_arg -j${XREPO_BUILD_PARALLEL_JOBS})
endif()
message(STATUS "xrepo: ${XREPO_CMD} install --mode=${_qbt_xrepo_mode} --configs=${_qbt_libtorrent_xrepo_configs} ${_qbt_libtorrent_xrepo_package}")
execute_process(
    COMMAND ${CMAKE_COMMAND} -E env --unset=CC --unset=CXX --unset=LD
        ${XREPO_CMD} install --yes ${_qbt_xrepo_build_parallel_jobs_arg}
        --mode=${_qbt_xrepo_mode}
        --configs=${_qbt_libtorrent_xrepo_configs}
        "${_qbt_libtorrent_xrepo_package}"
    RESULT_VARIABLE _qbt_libtorrent_xrepo_exit_code
)
if(NOT "${_qbt_libtorrent_xrepo_exit_code}" STREQUAL "0")
    message(FATAL_ERROR "xrepo install libtorrent-rasterbar failed, exit code: ${_qbt_libtorrent_xrepo_exit_code}")
endif()

file(TO_CMAKE_PATH "$ENV{LOCALAPPDATA}" _qbt_xrepo_localappdata)
file(TO_CMAKE_PATH "$ENV{USERPROFILE}" _qbt_xrepo_userprofile)
file(TO_CMAKE_PATH "$ENV{HOME}" _qbt_xrepo_home)
file(GLOB _qbt_libtorrent_xrepo_prefixes
    "${_qbt_xrepo_localappdata}/.xmake/packages/l/libtorrent-rasterbar/1.2.20/*"
    "${_qbt_xrepo_userprofile}/.xmake/packages/l/libtorrent-rasterbar/1.2.20/*"
    "${_qbt_xrepo_home}/.xmake/packages/l/libtorrent-rasterbar/1.2.20/*"
)
list(FILTER _qbt_libtorrent_xrepo_prefixes EXCLUDE REGEX "/(cache|source)$")
list(LENGTH _qbt_libtorrent_xrepo_prefixes _qbt_libtorrent_xrepo_prefix_count)
if(_qbt_libtorrent_xrepo_prefix_count EQUAL 0)
    message(FATAL_ERROR "Cannot locate xrepo-installed libtorrent-rasterbar prefix")
endif()
list(GET _qbt_libtorrent_xrepo_prefixes 0 _qbt_libtorrent_xrepo_prefix)
list(PREPEND CMAKE_PREFIX_PATH "${_qbt_libtorrent_xrepo_prefix}")
message(STATUS "xrepo: libtorrent-rasterbar prepend to CMAKE_PREFIX_PATH: ${_qbt_libtorrent_xrepo_prefix}")

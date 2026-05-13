# StaticQtPlugins.cmake
#
# Included via CMAKE_PROJECT_INCLUDE. Uses cmake_language(DEFER) to inject
# static Qt plugin support into qbt_app after all subdirectories are processed.

if(CMAKE_VERSION VERSION_LESS "3.19")
    message(FATAL_ERROR "StaticQtPlugins.cmake requires CMake 3.19+ for cmake_language(DEFER)")
endif()

cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL _qbt_setup_static_qt_plugins)

function(_qbt_setup_static_qt_plugins)
    if(NOT TARGET qbt_app)
        message(STATUS "StaticQtPlugins: qbt_app target not found, skipping")
        return()
    endif()

    # Conan CMakeDeps creates non-GLOBAL IMPORTED targets, so they are only
    # visible in the subdirectory scope where find_package() was called.
    # Re-run find_package here to make the targets visible in this scope.
    find_package(Qt5 COMPONENTS Core Gui QUIET)

    if(NOT TARGET Qt5::Core)
        message(STATUS "StaticQtPlugins: Qt5::Core target not found after re-find, skipping")
        return()
    endif()

    # Check if Qt is static
    get_target_property(_qt_core_type Qt5::Core TYPE)
    if(NOT _qt_core_type STREQUAL "STATIC_LIBRARY" AND NOT _qt_core_type STREQUAL "INTERFACE_LIBRARY")
        message(STATUS "StaticQtPlugins: Qt5::Core is ${_qt_core_type}, not static - skipping")
        return()
    endif()

    message(STATUS "StaticQtPlugins: Static Qt detected - importing platform plugins for qbt_app")

    # Add the plugin import source file
    target_sources(qbt_app PRIVATE "${CMAKE_SOURCE_DIR}/cmake/static_qt_plugins.cpp")

    # Link the platform integration plugin
    if(TARGET Qt5::QWindowsIntegrationPlugin)
        target_link_libraries(qbt_app PRIVATE Qt5::QWindowsIntegrationPlugin)
        message(STATUS "StaticQtPlugins: Linked Qt5::QWindowsIntegrationPlugin target")
    else()
        # Fallback: search for qwindows.lib in Conan package paths
        foreach(_prefix IN LISTS CMAKE_PREFIX_PATH)
            list(APPEND _hints
                "${_prefix}/plugins/platforms"
                "${_prefix}/res/archdatadir/plugins/platforms"
            )
        endforeach()
        find_library(QWINDOWS_PLUGIN_LIB qwindows HINTS ${_hints})
        if(QWINDOWS_PLUGIN_LIB)
            target_link_libraries(qbt_app PRIVATE "${QWINDOWS_PLUGIN_LIB}")
            message(STATUS "StaticQtPlugins: Found qwindows at ${QWINDOWS_PLUGIN_LIB}")
        else()
            message(FATAL_ERROR "StaticQtPlugins: Cannot find qwindows plugin lib")
        endif()
    endif()

    # Windows system libraries required by QWindowsIntegrationPlugin
    target_link_libraries(qbt_app PRIVATE dwmapi imm32 oleaut32 wtsapi32)
endfunction()

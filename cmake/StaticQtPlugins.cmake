# StaticQtPlugins.cmake
#
# Included via CMAKE_PROJECT_INCLUDE. Conan CMakeDeps does not auto-import Qt
# static plugins the way vcpkg does, so link the required plugin libraries and
# register them from cmake/static_qt_plugins.cpp.

if(CMAKE_VERSION VERSION_LESS "3.19")
    message(FATAL_ERROR "StaticQtPlugins.cmake requires CMake 3.19+ for cmake_language(DEFER)")
endif()

cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL _qbt_setup_static_qt_plugins)

function(_qbt_link_qt_plugin _target _lib _category)
    if(TARGET Qt5::${_target})
        target_link_libraries(qbt_app PRIVATE Qt5::${_target})
        message(STATUS "StaticQtPlugins: Linked Qt5::${_target}")
        return()
    endif()

    set(_hints)
    foreach(_prefix IN LISTS CMAKE_PREFIX_PATH)
        list(APPEND _hints
            "${_prefix}/plugins/${_category}"
            "${_prefix}/res/archdatadir/plugins/${_category}"
        )
    endforeach()

    get_target_property(_qt_core_lib Qt5::Core IMPORTED_LOCATION_RELWITHDEBINFO)
    if(NOT _qt_core_lib)
        get_target_property(_qt_core_lib Qt5::Core IMPORTED_LOCATION_RELEASE)
    endif()
    if(NOT _qt_core_lib)
        get_target_property(_qt_core_lib Qt5::Core IMPORTED_LOCATION)
    endif()
    if(_qt_core_lib)
        get_filename_component(_qt_lib_dir "${_qt_core_lib}" DIRECTORY)
        list(APPEND _hints
            "${_qt_lib_dir}/../plugins/${_category}"
            "${_qt_lib_dir}/../res/archdatadir/plugins/${_category}"
        )
    endif()

    set(_lib_var "QBT_${_target}_LIB")
    find_library(${_lib_var} ${_lib} HINTS ${_hints})
    if(NOT ${_lib_var})
        message(FATAL_ERROR "StaticQtPlugins: Cannot find ${_lib} plugin library for Qt5::${_target}")
    endif()

    target_link_libraries(qbt_app PRIVATE "${${_lib_var}}")
    message(STATUS "StaticQtPlugins: Found ${_lib} at ${${_lib_var}}")
endfunction()

function(_qbt_setup_static_qt_plugins)
    if(NOT TARGET qbt_app)
        message(STATUS "StaticQtPlugins: qbt_app target not found, skipping")
        return()
    endif()

    # Conan CMakeDeps creates non-GLOBAL IMPORTED targets, so re-run
    # find_package() here to make Qt plugin targets visible in this scope.
    find_package(Qt5 COMPONENTS Core Gui Widgets Svg Sql Network QUIET)

    if(NOT TARGET Qt5::Core)
        message(STATUS "StaticQtPlugins: Qt5::Core target not found after re-find, skipping")
        return()
    endif()

    get_target_property(_qt_core_type Qt5::Core TYPE)
    if(NOT _qt_core_type STREQUAL "STATIC_LIBRARY" AND NOT _qt_core_type STREQUAL "INTERFACE_LIBRARY")
        message(STATUS "StaticQtPlugins: Qt5::Core is ${_qt_core_type}, not static - skipping")
        return()
    endif()

    message(STATUS "StaticQtPlugins: Static Qt detected - importing plugins for qbt_app")

    target_sources(qbt_app PRIVATE "${CMAKE_SOURCE_DIR}/cmake/static_qt_plugins.cpp")

    # QSvgIconPlugin/QSvgPlugin use QSvgRenderer symbols from Qt5::Svg.
    if(NOT TARGET Qt5::Svg)
        message(FATAL_ERROR "StaticQtPlugins: Qt5::Svg is required")
    endif()
    target_link_libraries(qbt_app PRIVATE Qt5::Svg)

    # QICOPlugin is already imported by src/app/main.cpp when QBT_STATIC_QT is set;
    # keep source untouched and only provide the plugin library here.
    _qbt_link_qt_plugin(QICOPlugin qico imageformats)

    _qbt_link_qt_plugin(QWindowsIntegrationPlugin qwindows platforms)
    _qbt_link_qt_plugin(QWindowsVistaStylePlugin qwindowsvistastyle styles)
    _qbt_link_qt_plugin(QSvgIconPlugin qsvgicon iconengines)
    _qbt_link_qt_plugin(QSvgPlugin qsvg imageformats)
    _qbt_link_qt_plugin(QSQLiteDriverPlugin qsqlite sqldrivers)

    target_link_libraries(qbt_app PRIVATE dwmapi imm32 oleaut32 wtsapi32)
endfunction()

vcpkg_from_git(
    OUT_SOURCE_PATH SOURCE_PATH
    URL https://github.com/openssl/openssl.git
    REF 529ba79d5b9cc7e7139c32819e995cb123ab6f93
)

vcpkg_find_acquire_program(PERL)

get_filename_component(PERL_PATH "${PERL}" DIRECTORY)
vcpkg_add_to_path("${PERL_PATH}")

if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_find_acquire_program(NASM)
    get_filename_component(NASM_PATH "${NASM}" DIRECTORY)
    vcpkg_add_to_path("${NASM_PATH}")

    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(OPENSSL_PLATFORM VC-WIN64A)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(OPENSSL_PLATFORM VC-WIN64-ARM)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        set(OPENSSL_PLATFORM VC-WIN32)
    else()
        message(FATAL_ERROR "Unsupported OpenSSL target architecture: ${VCPKG_TARGET_ARCHITECTURE}")
    endif()
    set(OPENSSL_BUILD_COMMAND nmake /nologo)
elseif(VCPKG_TARGET_IS_OSX)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(OPENSSL_PLATFORM darwin64-x86_64-cc)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(OPENSSL_PLATFORM darwin64-arm64-cc)
    else()
        message(FATAL_ERROR "Unsupported OpenSSL target architecture: ${VCPKG_TARGET_ARCHITECTURE}")
    endif()
    set(OPENSSL_BUILD_COMMAND make -j${VCPKG_CONCURRENCY})
elseif(VCPKG_TARGET_IS_LINUX)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(OPENSSL_PLATFORM linux-x86_64)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(OPENSSL_PLATFORM linux-aarch64)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        set(OPENSSL_PLATFORM linux-x86)
    else()
        message(FATAL_ERROR "Unsupported OpenSSL target architecture: ${VCPKG_TARGET_ARCHITECTURE}")
    endif()
    set(OPENSSL_BUILD_COMMAND make -j${VCPKG_CONCURRENCY})
else()
    message(FATAL_ERROR "Unsupported OpenSSL target platform")
endif()

set(OPENSSL_OPTIONS no-tests)
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    list(APPEND OPENSSL_OPTIONS no-shared)
endif()

vcpkg_execute_required_process(
    COMMAND
        "${PERL}" Configure
        "${OPENSSL_PLATFORM}"
        ${OPENSSL_OPTIONS}
        "--prefix=${CURRENT_PACKAGES_DIR}"
        "--openssldir=${CURRENT_PACKAGES_DIR}/ssl"
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME configure-${TARGET_TRIPLET}
)

vcpkg_execute_required_process(
    COMMAND ${OPENSSL_BUILD_COMMAND}
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME build-${TARGET_TRIPLET}
)

vcpkg_execute_required_process(
    COMMAND ${OPENSSL_BUILD_COMMAND} install_sw
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME install-${TARGET_TRIPLET}
)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/ssl/misc")
file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

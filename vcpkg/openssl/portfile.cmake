if(NOT VCPKG_TARGET_IS_WINDOWS)
    message(FATAL_ERROR "This OpenSSL 1.1.1w overlay is only intended for the Windows CI build.")
endif()

vcpkg_from_git(
    OUT_SOURCE_PATH SOURCE_PATH
    URL https://github.com/openssl/openssl.git
    REF 529ba79d5b9cc7e7139c32819e995cb123ab6f93
)

vcpkg_find_acquire_program(PERL)
vcpkg_find_acquire_program(NASM)

get_filename_component(PERL_PATH "${PERL}" DIRECTORY)
get_filename_component(NASM_PATH "${NASM}" DIRECTORY)
vcpkg_add_to_path("${PERL_PATH}")
vcpkg_add_to_path("${NASM_PATH}")

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(OPENSSL_PLATFORM VC-WIN64A)
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
    set(OPENSSL_PLATFORM VC-WIN32)
else()
    message(FATAL_ERROR "Unsupported OpenSSL target architecture: ${VCPKG_TARGET_ARCHITECTURE}")
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
    COMMAND nmake /nologo
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME build-${TARGET_TRIPLET}
)

vcpkg_execute_required_process(
    COMMAND nmake /nologo install_sw
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME install-${TARGET_TRIPLET}
)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/ssl/misc")
file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

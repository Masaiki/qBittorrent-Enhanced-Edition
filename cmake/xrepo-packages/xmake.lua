package("libtorrent-rasterbar")
    set_homepage("https://www.libtorrent.org/")
    set_description("An efficient feature complete C++ BitTorrent implementation")
    set_license("BSD-3-Clause")

    add_urls("https://github.com/arvidn/libtorrent.git")
    add_versions("1.2.20", "v1.2.20")

    add_configs("deprecated_functions", {description = "Enable deprecated libtorrent APIs.", default = true, type = "boolean"})
    add_configs("iconv", {description = "Enable iconv support.", default = false, type = "boolean"})

    add_deps("cmake", "boost", "openssl", "zlib")

    on_fetch(function (package, opt)
        local installdir = package:installdir()
        return {
            version = package:version_str(),
            includedirs = path.join(installdir, "include"),
            linkdirs = path.join(installdir, "lib"),
            links = "torrent-rasterbar"
        }
    end)

    on_install("windows", function (package)
        local configs = {
            "-DCMAKE_CXX_STANDARD=17",
            "-DCMAKE_BUILD_TYPE=" .. (package:debug() and "Debug" or "Release"),
            "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"),
            "-Ddeprecated-functions=" .. (package:config("deprecated_functions") and "ON" or "OFF"),
            "-Diconv=" .. (package:config("iconv") and "ON" or "OFF"),
            "-Dbuild_examples=OFF",
            "-Dbuild_tests=OFF",
            "-Dbuild_tools=OFF",
            "-Dpython-bindings=OFF",
            "-DPython3_USE_STATIC_LIBS=ON"
        }

        if package:config("vs_runtime") == "MT" or package:config("vs_runtime") == "MTd" then
            table.insert(configs, "-Dstatic_runtime=ON")
        end

        import("package.tools.cmake").install(package, configs, {packagedeps = {"boost", "openssl", "zlib"}})
    end)

    on_test(function (package)
        assert(package:has_cxxincludes("libtorrent/session.hpp", {configs = {languages = "c++17"}}))
    end)

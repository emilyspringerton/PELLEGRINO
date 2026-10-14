"""mbedTLS 3.6 LTS, built from source with PELLEGRINO's user config (see pellegrino_user_config.h).

Linux/Bazel build only; the Windows bundle compiles the same sources with mingw in
scripts/package_windows.sh."""

load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "mbedtls",
    srcs = glob([
        "library/*.c",
        "library/*.h",
    ]),
    hdrs = glob(["include/**/*.h"]),
    defines = ["MBEDTLS_USER_CONFIG_FILE=\\\"pellegrino_user_config.h\\\""],
    includes = ["include"],
    visibility = ["//visibility:public"],
    deps = ["@pellegrino//third_party/mbedtls:user_config"],
)

load("@rules_terraform//terraform:platform.bzl", "cpu_constraints", "os_constraints", "parse_platform")
load("@rules_terraform//terraform:rules.bzl", "tf_provider")
load(":rules.bzl", "provider_src")

provider_src(
    name = "src",
)

tf_provider(
    name = "provider",
    hostname = %{hostname},
    namespace = %{namespace},
    src = ":src",
    type = %{type},
    version = %{version},
    visibility = ["//visibility:public"],
)

toolchain_type(
    name = "toolchain_type",
)

[
    toolchain(
        name = "toolchain_%s_%s" % (os, cpu),
        exec_compatible_with = [cpu_constraint, os_constraint],
        toolchain = provider,
        toolchain_type = ":toolchain_type",
    )
    for platform, provider in %{toolchains}.items()
    for os, os_constraint in os_constraints(parse_platform(platform).os).items()
    for cpu, cpu_constraint in cpu_constraints(parse_platform(platform).arch).items()
]

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")
load(":terraform.bzl", "TERRAFORM_REPOS")

def tf_repositories(version = "1.4.2"):
    for platform, info in TERRAFORM_REPOS[version].items():
        http_archive(
            name = "terraform_%s" % platform,
            build_file = "@rules_terraform//terraform:terraform.bazel",
            sha256 = info.sha256,
            url = "https://releases.hashicorp.com/terraform/%s/terraform_%s_%s.zip" % (version, version, platform),
        )

def tf_toolchains():
    native.register_toolchains(
        "@rules_terraform//terraform:linux_amd64_toolchain",
        "@rules_terraform//terraform:linux_arm64_toolchain",
        "@rules_terraform//terraform:macos_amd64_toolchain",
        "@rules_terraform//terraform:macos_arm64_toolchain",
        "@rules_terraform//terraform:windows_amd64_toolchain",
    )

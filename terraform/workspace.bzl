load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load(":platform.bzl", "PLATFORMS", "cpu_constraints", "os_constraints", "parse_platform")
load(":terraform.bzl", "TERRAFORM_REPOS")

def _tf_provider_impl(ctx):
    hostname = ctx.attr.hostname
    namespace = ctx.attr.namespace
    platforms = ctx.attr.platforms
    version = ctx.attr.version
    type = ctx.attr.type

    ctx.template(
        "BUILD.bazel",
        Label("provider-build.bazel.tpl"),
        substitutions = {
            "%{hostname}": json.encode(hostname),
            "%{namespace}": json.encode(namespace),
            "%{toolchains}": json.encode(platforms),
            "%{type}": json.encode(type),
            "%{version}": json.encode(version),
        },
    )

    ctx.template(
        "rules.bzl",
        Label("provider-rules.bzl"),
    )

tf_provider = repository_rule(
    attrs = {
        "hostname": attr.string(mandatory = True),
        "namespace": attr.string(mandatory = True),
        "platforms": attr.string_dict(),
        "type": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
    implementation = _tf_provider_impl,
)

def tf_providers(name, providers):
    for provider_name, provider in providers.items():
        platforms = {}
        for platform, package in provider.platforms.items():
            repo_name = "%s_%s_%s" % (name, provider_name, platform)
            platforms[platform] = "@%s//:provider" % repo_name
            http_archive(
                name = repo_name,
                add_prefix = "files",
                build_file = "@rules_terraform//terraform:provider-platform-build.bazel",
                sha256 = package.sha256,
                url = package.url,
            )
            parsed = parse_platform(platform)
            native.register_toolchains(*[
                "@%s_%s//:toolchain_%s_%s" % (name, provider_name, os, cpu)
                for os in os_constraints(parsed.os)
                for cpu in cpu_constraints(parsed.arch)
            ])
        tf_provider(
            name = "%s_%s" % (name, provider_name),
            hostname = provider.hostname,
            namespace = provider.namespace,
            platforms = platforms,
            type = provider.type,
            version = provider.version,
        )

def tf_repositories(version = "1.4.2"):
    for platform, info in TERRAFORM_REPOS[version].items():
        http_archive(
            name = "terraform_%s" % platform,
            build_file = "@rules_terraform//terraform:terraform.bazel",
            sha256 = info.sha256,
            url = "https://releases.hashicorp.com/terraform/%s/terraform_%s_%s.zip" % (version, version, platform),
        )

def tf_toolchains():
    native.register_toolchains(*[
        "@rules_terraform//terraform/default:terraform_%s_%s_toolchain" % (os, cpu)
        for platform in PLATFORMS
        for os in os_constraints(platform.os)
        for cpu in cpu_constraints(platform.arch)
    ])
    native.register_toolchains(*[
        "@rules_terraform//terraform/default:platform_%s_%s_toolchain" % (os, cpu)
        for platform in PLATFORMS
        for os in os_constraints(platform.os)
        for cpu in cpu_constraints(platform.arch)
    ])

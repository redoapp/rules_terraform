load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load(":platform.bzl", "PLATFORMS", "cpu_constraints", "os_constraints", "parse_platform")
load(":provider.bzl", "provider_toolchain_name")
load("//terraform/default:terraform.bzl", "TERRAFORM")

def _tf_provider_impl(ctx):
    hostname = ctx.attr.hostname
    namespace = ctx.attr.namespace
    toolchains = ctx.attr.toolchains
    version = ctx.attr.version
    type = ctx.attr.type

    ctx.template(
        "BUILD.bazel",
        Label("provider-build.bazel.tpl"),
        substitutions = {
            "%{hostname}": json.encode(hostname),
            "%{namespace}": json.encode(namespace),
            "%{toolchains}": json.encode(toolchains),
            "%{type}": json.encode(type),
            "%{version}": json.encode(version),
        },
    )

    ctx.template(
        "rules.bzl",
        Label("provider-rules.bzl"),
    )

_tf_provider = repository_rule(
    attrs = {
        "hostname": attr.string(doc = "Canonical hostname", mandatory = True),
        "namespace": attr.string(doc = "Namespace", mandatory = True),
        "toolchains": attr.string_dict(doc = "Map of platform to toolchain"),
        "type": attr.string(doc = "Type", mandatory = True),
        "version": attr.string(doc = "Version", mandatory = True),
    },
    implementation = _tf_provider_impl,
)

def tf_providers(name, providers):
    for provider_name, provider in providers.items():
        repo_name = "%s_%s" % (name, provider_name)
        toolchains = {}
        for platform, package in provider.platforms.items():
            platform_repo_name = "%s_%s_%s" % (name, provider_name, platform)
            toolchains[platform] = "@%s//:provider" % platform_repo_name
            http_archive(
                name = platform_repo_name,
                add_prefix = "files",
                build_file = "@rules_terraform//terraform:provider-platform-build.bazel",
                sha256 = package.sha256,
                url = package.url,
            )
            parsed = parse_platform(platform)
            native.register_toolchains(*[
                "@%s//:%s" % (repo_name, provider_toolchain_name(os, cpu))
                for os in os_constraints(parsed.os)
                for cpu in cpu_constraints(parsed.arch)
            ])
        _tf_provider(
            name = repo_name,
            hostname = provider.hostname,
            namespace = provider.namespace,
            toolchains = toolchains,
            type = provider.type,
            version = provider.version,
        )

def tf_platforms():
    native.register_toolchains(*[
        "@rules_terraform//terraform/default:platform_%s_%s_toolchain" % (os, cpu)
        for platform in PLATFORMS
        for os in os_constraints(platform.os)
        for cpu in cpu_constraints(platform.arch)
    ])

def tf_toolchains(version):
    if version not in TERRAFORM:
        fail("Terraform version %s not in %s" % (version, ", ".join(TERRAFORM.keys())))

    for platform, info in TERRAFORM[version].items():
        http_archive(
            name = "terraform_%s" % platform,
            build_file = "@rules_terraform//terraform:terraform.bazel",
            sha256 = info.sha256,
            url = "https://releases.hashicorp.com/terraform/%s/terraform_%s_%s.zip" % (version, version, platform),
        )

        os, arch = platform.split("_")

        native.register_toolchains(*[
            "@rules_terraform//terraform/default:terraform_%s_%s_toolchain" % (os, cpu)
            for os in os_constraints(os)
            for cpu in cpu_constraints(arch)
        ])

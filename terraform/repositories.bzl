def _tf_http_archive_impl(ctx):
    ctx.template(
        "BUILD.bazel",
        Label("terraform.BUILD.bazel"),
        substitutions = {
            '"%{arch}"': repr(ctx.attr.arch),
            '"%{os}"': repr(ctx.attr.os),
            '"%{rules}"': repr(str(Label("rules.bzl"))),
        },
    )

    ctx.download_and_extract(
        url = ctx.attr.url,
        sha256 = ctx.attr.sha256,
    )

tf_http_archive = repository_rule(
    attrs = {
        "arch": attr.string(mandatory = True),
        "os": attr.string(mandatory = True),
        "sha256": attr.string(mandatory = True),
        "url": attr.string(mandatory = True),
    },
    implementation = _tf_http_archive_impl,
)

def _tf_provider_impl(ctx):
    hostname = ctx.attr.hostname
    namespace = ctx.attr.namespace
    version = ctx.attr.version
    type = ctx.attr.type

    ctx.template(
        "BUILD.bazel",
        Label("provider.BUILD.bazel"),
        substitutions = {
            '"%{hostname}"': repr(hostname),
            '"%{namespace}"': repr(namespace),
            '"%{rules}"': repr(str(Label("rules.bzl"))),
            '"%{type}"': repr(type),
            '"%{version}"': repr(version),
        },
    )

    ctx.template(
        "rules.bzl",
        Label("provider-rules.bzl"),
        substitutions = {
            '"%{provider}"': repr(str(Label("provider.bzl"))),
        },
    )

tf_provider = repository_rule(
    attrs = {
        "hostname": attr.string(doc = "Canonical hostname", mandatory = True),
        "namespace": attr.string(doc = "Namespace", mandatory = True),
        "type": attr.string(doc = "Type", mandatory = True),
        "version": attr.string(doc = "Version", mandatory = True),
    },
    implementation = _tf_provider_impl,
)

def _tf_provider_toolchain_impl(ctx):
    sha256 = ctx.attr.sha256
    url = ctx.attr.url

    ctx.template(
        "BUILD.bazel",
        Label("provider-toolchain.BUILD.bazel"),
        substitutions = {
            '"%{file_rules}"': repr(str(Label("@bazel_util//file:rules.bzl"))),
            '"%{rules}"': repr(str(Label("rules.bzl"))),
        },
    )

    ctx.download_and_extract(
        sha256 = sha256,
        url = url,
    )

tf_provider_toolchain = repository_rule(
    attrs = {
        "sha256": attr.string(doc = "SHA256", mandatory = True),
        "url": attr.string(doc = "URL", mandatory = True),
    },
    implementation = _tf_provider_toolchain_impl,
)

def _tf_provider_toolchains_impl(ctx):
    repositories = ctx.attr.repositories

    ctx.template(
        "BUILD.bazel",
        Label("provider-toolchains.BUILD.bazel"),
        substitutions = {
            '["%{repositories}"]': repr(repositories),
            '"%{rules}"': repr(str(Label("rules.bzl"))),
        },
    )

tf_provider_toolchains = repository_rule(
    attrs = {
        "repositories": attr.string_list(),
    },
    implementation = _tf_provider_toolchains_impl,
)

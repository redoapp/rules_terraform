load("@bazel_skylib//lib:versions.bzl", "versions")
load("//util:sha256sums.bzl", "sha256sums_parse")
load("//util:url.bzl", "url_resolve")
load(":repositories.bzl", "tf_http_archive", "tf_provider", "tf_provider_toolchain", "tf_provider_toolchains")

toolchain_tag = tag_class(
    attrs = {
        "version": attr.string(mandatory = True),
    },
)

provider_tag = tag_class(
    attrs = {
        "name": attr.string(mandatory = True),
        "address": attr.string(mandatory = True, default = "registry.terraform.io"),
        "version": attr.string(mandatory = True),
    },
)

def _terraform_impl(ctx):
    facts = ctx.facts.get(_FACTS_KEY)
    if facts and facts["_version"] != _FACTS_VERSION:
        facts = None

    version = None
    for module in ctx.modules:
        for toolchain in module.tags.toolchain:
            if version == None or versions.is_at_least(version, toolchain.version):
                if version != None:
                    print("Warning: replacing Terraform version %s with %s" % (version, toolchain.version))
                version = toolchain.version

    version = version or "1.14.5"

    sha256s = facts and facts.get("sha256s")
    if sha256s == None or facts.get("version") != version:
        ctx.download(
            output = "SHA256SUMS",
            url = "https://releases.hashicorp.com/terraform/{version}/terraform_{version}_SHA256SUMS".format(version = version),
        )
        sha256s = sha256sums_parse(ctx.read("SHA256SUMS"))

    for path, sha256 in sha256s.items():
        if not path.startswith("terraform_%s_" % version) or not path.endswith(".zip"):
            continue
        os, arch = path[len("terraform_%s_" % version):-len(".zip")].split("_")
        tf_http_archive(
            arch = arch,
            name = "terraform_%s" % path[len("terraform_%s_" % version):-len(".zip")],
            os = os,
            sha256 = sha256,
            url = "https://releases.hashicorp.com/terraform/%s/%s" % (version, path),
        )

    repositories = []

    providers = facts and facts.get("providers")
    new_providers = {}
    for module in ctx.modules:
        for provider in module.tags.provider:
            provider_key = "%s/%s" % (provider.address, provider.version)
            provider_facts = new_providers.get(provider_key)
            if provider_facts == None:
                provider_facts = providers and providers.get(provider_key)
                provider_facts = provider_facts or _resolve_provider(ctx, path = "providers/%s" % provider.name, provider = provider)
                new_providers[provider_key] = provider_facts

            hostname, namespace, type = provider.address.split("/")

            tf_provider(
                name = provider.name,
                hostname = hostname,
                namespace = namespace,
                type = type,
                version = provider.version,
            )
            repositories.append(provider.name)

            for platform_key, platform in provider_facts.items():
                name = "%s_%s" % (provider.name, platform_key.replace("-", "_"))
                tf_provider_toolchain(
                    name = name,
                    sha256 = platform["sha256"],
                    url = platform["url"],
                )
    providers = new_providers

    tf_provider_toolchains(
        name = "terraform_provider_toolchains",
        repositories = repositories,
    )

    return ctx.extension_metadata(
        facts = {_FACTS_KEY: {"providers": providers, "sha256s": sha256s, "version": version, "_version": _FACTS_VERSION}},
        reproducible = True,
    )

terraform = module_extension(
    implementation = _terraform_impl,
    tag_classes = {
        "provider": provider_tag,
        "toolchain": toolchain_tag,
    },
)

_FACTS_KEY = "_"

_FACTS_VERSION = "1"

def _resolve_provider(ctx, path, provider):
    result = {}
    hostname, namespace, type = provider.address.split("/")

    discovery_url = "https://%s/.well-known/terraform.json" % hostname
    ctx.download(
        output = "%s/terraform.json" % path,
        url = discovery_url,
    )
    terraform = json.decode(ctx.read("providers/%s/terraform.json" % provider.name))

    providers_url = url_resolve(discovery_url, terraform["providers.v1"])
    ctx.download(
        output = "%s/versions.json" % path,
        url = "%s%s/%s/versions" % (providers_url, namespace, type),
    )
    versions = json.decode(ctx.read("providers/%s/versions.json" % provider.name))

    matching_versions = [version for version in versions["versions"] if version["version"] == provider.version]
    if not matching_versions:
        fail("Provider %s version %s does not exist" % (provider.address, provider.version))
    for platform in matching_versions[0]["platforms"]:
        version_platform_path = "%s/%s_%s.json" % (path, platform["os"], platform["arch"])
        ctx.download(
            output = version_platform_path,
            url = "%s%s/%s/%s/download/%s/%s" % (providers_url, namespace, type, provider.version, platform["os"], platform["arch"]),
        )
        version_platform = json.decode(ctx.read(version_platform_path))

        result["%s-%s" % (platform["os"], platform["arch"])] = {
            "sha256": version_platform["shasum"],
            "url": version_platform["download_url"],
        }

    return result
